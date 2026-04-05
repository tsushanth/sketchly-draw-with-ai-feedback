/**
 * Sketchly Agent — Custom Drawing Lesson Service
 *
 * Endpoints:
 *   POST /custom/lesson     — User gives a subject, we find an outline and create the lesson
 *   POST /custom/evaluate   — Evaluate user drawing for a step
 *   POST /custom/revisit    — Go back and improve a weak step
 *   GET  /custom/session/:id — Get current session state
 *
 * Runs alongside other workers on the Hetzner VM.
 * Sessions are in-memory only — progress is lost when user leaves.
 *
 * Start: ANTHROPIC_API_KEY=... WORKER_SECRET=... node server.js
 */

import express from 'express';
import Anthropic from '@anthropic-ai/sdk';
import crypto from 'crypto';

const app = express();
app.use(express.json({ limit: '20mb' }));

const PORT = process.env.PORT || process.env.SKETCHLY_PORT || 3458;
const WORKER_SECRET = process.env.WORKER_SECRET || '';
const ANTHROPIC_API_KEY = process.env.ANTHROPIC_API_KEY || '';

const anthropic = new Anthropic({ apiKey: ANTHROPIC_API_KEY });

// ============================================
// Auth middleware
// ============================================

function auth(req, res, next) {
    if (!WORKER_SECRET) {
        return res.status(500).json({ error: 'Server not configured: missing WORKER_SECRET' });
    }
    const token = req.headers['x-worker-secret'] || req.headers['authorization']?.replace('Bearer ', '');
    if (token === WORKER_SECRET) {
        return next();
    }
    res.status(401).json({ error: 'Unauthorized' });
}

// ============================================
// Session store (in-memory, TTL 30 min)
// ============================================

const sessions = new Map();
const SESSION_TTL = 30 * 60 * 1000; // 30 minutes

function createSession(data) {
    const id = crypto.randomUUID();
    const session = { id, ...data, createdAt: Date.now(), lastAccess: Date.now() };
    sessions.set(id, session);
    return session;
}

function getSession(id) {
    const session = sessions.get(id);
    if (!session) return null;
    if (Date.now() - session.lastAccess > SESSION_TTL) {
        sessions.delete(id);
        return null;
    }
    session.lastAccess = Date.now();
    return session;
}

// Cleanup expired sessions every 5 min
setInterval(() => {
    const now = Date.now();
    for (const [id, session] of sessions) {
        if (now - session.lastAccess > SESSION_TTL) {
            sessions.delete(id);
        }
    }
}, 5 * 60 * 1000);

// ============================================
// POST /custom/lesson — Create lesson from subject
// User just says "wolf" or "face" — we find an
// outline image and decompose it into steps.
// ============================================

app.post('/custom/lesson', auth, async (req, res) => {
    try {
        const { subject, difficulty = 'beginner', mode = 'web' } = req.body;
        if (!subject || typeof subject !== 'string') {
            return res.status(400).json({ error: 'subject is required' });
        }

        let referenceImage = null;

        // mode: "web" = find real image, "ai" = generate SVG from description
        if (mode === 'web' && GOOGLE_CSE_KEY) {
            try {
                const images = await searchImages(subject);
                console.log(`Found ${images.length} images for "${subject}"`);

                for (const img of images) {
                    try {
                        const imageResponse = await fetch(img.url, { signal: AbortSignal.timeout(8000) });
                        if (!imageResponse.ok) continue;

                        const contentType = imageResponse.headers.get('content-type') || '';
                        if (!contentType.startsWith('image/')) continue;

                        const imageBuffer = Buffer.from(await imageResponse.arrayBuffer());
                        if (imageBuffer.length < 5000) continue;

                        referenceImage = {
                            base64: imageBuffer.toString('base64'),
                            mediaType: contentType,
                            sourceUrl: img.url,
                        };
                        console.log(`Using reference image from ${img.source}`);
                        break;
                    } catch {
                        continue;
                    }
                }
            } catch (err) {
                console.log(`Image search failed (${err.message}), falling back to AI mode`);
            }
        }

        // Decompose into lesson steps
        let plan;
        if (referenceImage) {
            plan = await decomposeImage(referenceImage.base64, referenceImage.mediaType, subject, difficulty);
        } else {
            plan = await generateFromDescription(subject, difficulty);
        }

        const session = createSession({
            subject,
            difficulty,
            referenceImage, // may be null if no image found
            plan,
            stepResults: {},
            currentStep: 0,
        });

        res.json({
            sessionId: session.id,
            subject: session.subject,
            totalSteps: plan.steps.length,
            estimatedMinutes: plan.steps.length * 2,
            currentStep: 0,
            step: plan.steps[0],
            hasReferenceImage: !!referenceImage,
            note: 'Lesson progress does not persist after you leave. Complete it in one sitting!'
        });
    } catch (err) {
        console.error('Lesson create error:', err.message);
        res.status(500).json({ error: 'Failed to create lesson: ' + err.message });
    }
});

// ============================================
// POST /custom/evaluate — Evaluate drawing
// ============================================

app.post('/custom/evaluate', auth, async (req, res) => {
    try {
        const { sessionId, stepIndex, imageBase64 } = req.body;
        if (!sessionId || stepIndex === undefined || !imageBase64) {
            return res.status(400).json({ error: 'sessionId, stepIndex, and imageBase64 are required' });
        }

        const session = getSession(sessionId);
        if (!session) {
            return res.status(404).json({ error: 'Session expired or not found' });
        }

        const { plan, referenceImage } = session;
        if (stepIndex < 0 || stepIndex >= plan.steps.length) {
            return res.status(400).json({ error: 'Invalid stepIndex' });
        }

        const step = plan.steps[stepIndex];

        // Build context from previous step results for continuity
        const priorContext = Object.values(session.stepResults)
            .filter(r => r.stepIndex < stepIndex)
            .map(r => `Step ${r.stepIndex + 1} (${plan.steps[r.stepIndex].description}): ${r.passed ? 'passed' : 'needs work'} - ${r.feedback}`)
            .join('\n');

        const evaluation = await evaluateStep(
            imageBase64,
            step,
            session.subject,
            referenceImage,
            priorContext
        );

        // Track attempts per step
        const existing = session.stepResults[stepIndex];
        if (existing) {
            existing.attempts += 1;
            existing.passed = evaluation.passed;
            existing.feedback = evaluation.feedback;
            existing.score = evaluation.score;
        } else {
            session.stepResults[stepIndex] = {
                stepIndex,
                passed: evaluation.passed,
                feedback: evaluation.feedback,
                score: evaluation.score,
                attempts: 1,
            };
        }

        // Determine next action
        const isLastStep = stepIndex === plan.steps.length - 1;

        let nextAction;
        if (evaluation.passed && isLastStep) {
            nextAction = 'complete';
        } else if (evaluation.passed) {
            session.currentStep = stepIndex + 1;
            nextAction = 'next';
        } else {
            nextAction = 'retry';
        }

        // Find weak steps the user might want to revisit
        const weakSteps = Object.values(session.stepResults)
            .filter(r => r.passed && r.score && r.score < 7)
            .map(r => ({
                stepIndex: r.stepIndex,
                description: plan.steps[r.stepIndex].description,
                score: r.score,
                suggestion: `You passed this step but could improve — score was ${r.score}/10`
            }));

        const response = {
            passed: evaluation.passed,
            feedback: evaluation.feedback,
            score: evaluation.score,
            nextAction,
            weakSteps,
        };

        if (nextAction === 'next') {
            response.nextStep = plan.steps[stepIndex + 1];
        }

        if (nextAction === 'complete') {
            // Generate summary
            const allResults = Object.values(session.stepResults);
            response.summary = {
                totalSteps: plan.steps.length,
                stepsCompleted: allResults.filter(r => r.passed).length,
                averageScore: Math.round(
                    allResults.reduce((sum, r) => sum + (r.score || 5), 0) / allResults.length
                ),
                totalAttempts: allResults.reduce((sum, r) => sum + r.attempts, 0),
                weakSteps,
            };
        }

        res.json(response);
    } catch (err) {
        console.error('Evaluate error:', err.message);
        res.status(500).json({ error: 'Evaluation failed' });
    }
});

// ============================================
// POST /custom/revisit — Go back to improve a step
// ============================================

app.post('/custom/revisit', auth, async (req, res) => {
    try {
        const { sessionId, stepIndex } = req.body;

        const session = getSession(sessionId);
        if (!session) {
            return res.status(404).json({ error: 'Session expired or not found' });
        }

        const { plan, stepResults } = session;
        if (stepIndex < 0 || stepIndex >= plan.steps.length) {
            return res.status(400).json({ error: 'Invalid stepIndex' });
        }

        const step = plan.steps[stepIndex];
        const prevResult = stepResults[stepIndex];

        session.currentStep = stepIndex;

        res.json({
            step,
            previousScore: prevResult?.score || null,
            previousFeedback: prevResult?.feedback || null,
            tip: prevResult
                ? `Last time you scored ${prevResult.score}/10. Focus on: ${prevResult.feedback}`
                : 'Give this step your best shot!',
        });
    } catch (err) {
        console.error('Revisit error:', err.message);
        res.status(500).json({ error: 'Failed to revisit step' });
    }
});

// ============================================
// GET /custom/session/:id — Session state
// ============================================

app.get('/custom/session/:id', auth, (req, res) => {
    const session = getSession(req.params.id);
    if (!session) {
        return res.status(404).json({ error: 'Session expired or not found' });
    }

    res.json({
        sessionId: session.id,
        subject: session.subject,
        difficulty: session.difficulty,
        totalSteps: session.plan.steps.length,
        currentStep: session.currentStep,
        steps: session.plan.steps.map((step, i) => {
            const result = session.stepResults[i];
            return {
                ...step,
                status: result ? (result.passed ? 'passed' : 'attempted') : 'pending',
                score: result?.score || null,
                attempts: result?.attempts || 0,
            };
        }),
    });
});

// ============================================
// Health check
// ============================================

app.get('/health', (_, res) => {
    res.json({
        service: 'sketchly-agent',
        status: 'ok',
        activeSessions: sessions.size,
        uptime: Math.floor(process.uptime()),
    });
});

// ============================================
// AI Functions
// ============================================

async function decomposeImage(base64Image, mediaType, subject, difficulty) {
    const stepCounts = { beginner: '8-10', intermediate: '6-8', advanced: '4-5' };
    const stepRange = stepCounts[difficulty] || '6-8';

    const response = await anthropic.messages.create({
        model: 'claude-sonnet-4-6',
        max_tokens: 4000,
        messages: [{
            role: 'user',
            content: [
                {
                    type: 'image',
                    source: { type: 'base64', media_type: mediaType, data: base64Image },
                },
                {
                    type: 'text',
                    text: `You are an expert drawing instructor. Analyze this reference image of "${subject}" and create a step-by-step drawing lesson.

TASK: Decompose this image into ${stepRange} achievable drawing steps. Each step should add new strokes that build toward the final image.

DECOMPOSITION STRATEGY:
1. Start with the largest anchor shape (e.g., head oval, body outline)
2. Use symmetry — if there are symmetric elements (eyes, ears), teach one side then mirror
3. Progress from structure to detail (big shapes → smaller shapes → fine details)
4. Each step should be achievable in 1-2 minutes of drawing
5. Group related elements (both eyes in one step, not separate steps)

CANVAS: 300x300 pixels. All coordinates must fit within this space.

SVG PATH RULES:
- ONLY use M, L, C, Q, Z commands (absolute). NO arcs (A command).
- For circles/ovals: use 4 cubic bezier curves with k=0.5523
- Each step's newSvgPath contains ONLY the new strokes for that step (not cumulative)
- Paths must be clean, valid SVG path data

Respond with ONLY valid JSON:
{
  "subject": "${subject}",
  "steps": [
    {
      "number": 1,
      "instruction": "<2-3 sentence spoken instruction explaining what to draw and HOW to draw it — mention direction, proportions, position>",
      "newSvgPath": "<SVG path data for ONLY this step's new strokes>",
      "description": "<short label like 'head oval' or 'both eyes'>",
      "symmetryHint": "<optional: 'mirror left to right' or null if not applicable>"
    }
  ]
}`
                },
            ],
        }],
    });

    const text = response.content[0]?.text || '';
    return parsePlan(text, subject);
}

async function evaluateStep(userImageBase64, step, subject, referenceImage, priorContext) {
    const contextBlock = priorContext
        ? `\n\nPRIOR STEPS:\n${priorContext}`
        : '';

    // Build message content — include reference image only if we have one
    const content = [];

    if (referenceImage) {
        content.push({
            type: 'image',
            source: { type: 'base64', media_type: referenceImage.mediaType, data: referenceImage.base64 },
        });
    }

    content.push({
        type: 'image',
        source: { type: 'base64', media_type: 'image/jpeg', data: userImageBase64 },
    });

    const refNote = referenceImage
        ? `REFERENCE: The first image is the full reference drawing of "${subject}".\nSTUDENT DRAWING: The second image is what the student just drew.`
        : `STUDENT DRAWING: The image is what the student just drew for "${subject}".`;

    content.push({
        type: 'text',
        text: `You are a friendly drawing instructor evaluating a student's attempt.

${refNote}
CURRENT STEP: "${step.description}" — ${step.instruction}
${contextBlock}

Evaluate whether the student's drawing reasonably matches what this step asked for.
Be encouraging but honest. Score 1-10 where 6+ means pass.

Respond with ONLY valid JSON:
{"passed": true/false, "score": <1-10>, "feedback": "<2-3 sentences: what they did well, one specific thing to improve>"}`
    });

    const response = await anthropic.messages.create({
        model: 'claude-sonnet-4-6',
        max_tokens: 300,
        messages: [{ role: 'user', content }],
    });

    const text = response.content[0]?.text || '';
    return parseEvaluation(text);
}

async function generateFromDescription(subject, difficulty) {
    // Fallback when no reference image found — generate SVG from description
    // (same approach the iOS app currently uses)
    const stepCounts = { beginner: '8-10', intermediate: '6-8', advanced: '4-5' };
    const stepRange = stepCounts[difficulty] || '6-8';

    const response = await anthropic.messages.create({
        model: 'claude-sonnet-4-6',
        max_tokens: 4000,
        messages: [{
            role: 'user',
            content: `You are an expert drawing instructor. Generate a ${stepRange}-step drawing lesson for "${subject}" (difficulty: ${difficulty}).

Canvas size: 300x300 pixels. Each step provides ONLY the NEW strokes for that step (not cumulative).

CRITICAL PATH RULES:
- ONLY use M, L, C, Q, Z commands. NO arcs (A command).
- For circles: use 4 cubic bezier curves with k=0.5523.
- Use realistic proportions within the 300x300 canvas.
- Each newSvgPath should be a complete, valid SVG path data string.

DECOMPOSITION STRATEGY:
1. Start with the largest anchor shape
2. Use symmetry for paired elements
3. Progress from structure to detail
4. Each step achievable in 1-2 minutes

Respond ONLY with valid JSON:
{
  "subject": "${subject}",
  "steps": [
    {
      "number": 1,
      "instruction": "<2-3 sentence spoken instruction>",
      "newSvgPath": "<SVG path data>",
      "description": "<short label>",
      "symmetryHint": null
    }
  ]
}`
        }],
    });

    const text = response.content[0]?.text || '';
    return parsePlan(text, subject);
}

// ============================================
// Image Search — Google Custom Search API
// ============================================

const GOOGLE_CSE_KEY = process.env.GOOGLE_CSE_KEY || '';
const GOOGLE_CSE_CX = process.env.GOOGLE_CSE_CX || '673567636ceb24bf9';

async function searchImages(query) {
    if (!GOOGLE_CSE_KEY) {
        throw new Error('Google Custom Search API key not configured');
    }

    const url = new URL('https://customsearch.googleapis.com/customsearch/v1');
    url.searchParams.set('key', GOOGLE_CSE_KEY);
    url.searchParams.set('cx', GOOGLE_CSE_CX);
    url.searchParams.set('q', `${query} outline drawing`);
    url.searchParams.set('searchType', 'image');
    url.searchParams.set('imgType', 'lineart');
    url.searchParams.set('imgColorType', 'mono');
    url.searchParams.set('num', '6');
    url.searchParams.set('safe', 'active');

    const response = await fetch(url.toString());
    if (!response.ok) {
        const body = await response.text();
        throw new Error(`Google CSE failed: ${response.status} - ${body.slice(0, 200)}`);
    }

    const data = await response.json();
    return (data.items || []).map(item => ({
        url: item.link,
        thumbnail: item.image?.thumbnailLink || item.link,
        width: item.image?.width || 0,
        height: item.image?.height || 0,
        source: item.displayLink,
    }));
}

// ============================================
// Parsing helpers
// ============================================

function extractJson(text) {
    const start = text.indexOf('{');
    const end = text.lastIndexOf('}');
    if (start !== -1 && end !== -1) {
        return text.slice(start, end + 1);
    }
    return text;
}

function parsePlan(text, fallbackSubject) {
    try {
        const json = JSON.parse(extractJson(text));
        const subject = json.subject || fallbackSubject;
        const steps = (json.steps || []).map((s, i) => ({
            number: s.number || i + 1,
            instruction: s.instruction || `Draw step ${i + 1}`,
            newSvgPath: s.newSvgPath || s.newSVGPath || 'M 0 0',
            description: s.description || `Step ${i + 1}`,
            symmetryHint: s.symmetryHint || null,
        }));

        if (steps.length === 0) {
            throw new Error('No steps in plan');
        }

        return { subject, steps };
    } catch (err) {
        throw new Error(`Failed to parse lesson plan: ${err.message}`);
    }
}

function parseEvaluation(text) {
    try {
        const json = JSON.parse(extractJson(text));
        const score = Math.min(10, Math.max(1, json.score || 5));
        return {
            passed: json.passed ?? score >= 6,
            score,
            feedback: json.feedback || 'Good effort! Keep going.',
        };
    } catch {
        return { passed: true, score: 6, feedback: 'Good effort! Keep going.' };
    }
}

// ============================================
// Start server
// ============================================

app.listen(PORT, '0.0.0.0', () => {
    console.log(`Sketchly Agent running on port ${PORT}`);
    console.log(`Active sessions: ${sessions.size}`);
    console.log(`Image search: ${GOOGLE_CSE_KEY ? 'Google Custom Search API' : 'disabled (no GOOGLE_CSE_KEY)'}`);
});
