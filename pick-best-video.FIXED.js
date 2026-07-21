// "Pick Best Video" — de-dupe + BRAND-RELEVANCE GATE (stops off-brand garbage).
//
// Paste this into the n8n node: workflow "YouTube Upload Analysis FIXED" →
// node "Pick Best Video" → Code field. (No API key needed — edit in the n8n UI.)
//
// What changed vs the old node:
//  1. RELEVANCE GATE: only tweet videos the "Content Curation" agent scored
//     >= RELEVANCY_MIN. The curator already assigns a relevancy_score per video
//     (seen in "Extract JSON" / "CHOOSE ONLY ONE"). The old node ignored it and
//     tweeted the highest *view-count* video — which is how viral off-brand junk
//     ("CIA Protocol", "capitalism is enforced") kept winning. Now junk is skipped.
//  2. If NOTHING qualifies → post nothing. Silence beats garbage.
//  3. DE-DUPE: never tweet the same video twice (persisted across runs).
//
// Tune RELEVANCY_MIN to your curator's scale (assumed ~1–10 here).

const FL_HOST = 'https://web.freelabel.net';
const RELEVANCY_MIN = 6;          // raise to be stricter; lower if too few posts
const published = $input.all();

// --- views + titles from FETCH YT DATA (keyed by youtube media id) ---
const views = {}, titles = {};
try {
  for (const it of $('FETCH YT DATA').all()) {
    const v = it.json && it.json.data && it.json.data.video;
    if (v && v.id) { views[v.id] = parseInt(v.viewCount || '0', 10) || 0; titles[v.id] = v.title; }
  }
} catch (e) { /* fall back to content titles */ }

// --- relevance/brand data from the curator (keyed by media id) ---
const relevance = {};
try {
  for (const it of $('Extract JSON').all()) {
    const d = it.json || {};
    if (d.media_id != null) {
      relevance[d.media_id] = {
        score: parseFloat(d.relevancy_score),
        marketing_title: d.marketing_title,
        profile_name: d.profile_name,
        reason: d.reason,
      };
    }
  }
} catch (e) { /* Extract JSON unavailable — gate falls back to "no score = skip" */ }

// --- build candidates: must have a real FL content id AND pass the relevance gate ---
const candidates = [];
for (const p of published) {
  const c = (p.json && p.json.data && p.json.data.content) || (p.json && p.json.content);
  if (!c || !c.id) continue;
  const mediaId = c.media_id;
  const rel = relevance[mediaId] || {};
  const score = isNaN(rel.score) ? null : rel.score;
  // GATE: skip anything the curator didn't score on-brand (null score = unknown = skip)
  if (score == null || score < RELEVANCY_MIN) continue;
  const title = rel.marketing_title || (mediaId && titles[mediaId]) || c.title || '';
  candidates.push({
    contentId: c.id,
    title,
    score,
    views: views[mediaId] != null ? views[mediaId] : 0,
    key: mediaId ? ('yt:' + mediaId) : ('title:' + title.toLowerCase().trim()),
  });
}
// best = highest relevance, then highest views
candidates.sort((a, b) => (b.score - a.score) || (b.views - a.views));

// --- DE-DUPE across executions ---
const staticData = $getWorkflowStaticData('global');
const MAX_REMEMBER = 300;
let posted = Array.isArray(staticData.postedKeys) ? staticData.postedKeys : [];
const postedSet = new Set(posted);
const best = candidates.find(c => c.key && !postedSet.has(c.key));

if (!best) return [];   // nothing on-brand and new → post nothing

posted.push(best.key);
if (posted.length > MAX_REMEMBER) posted = posted.slice(-MAX_REMEMBER);
staticData.postedKeys = posted;

const url = `${FL_HOST}/content/video/${best.contentId}`;
const tweet_text = [best.title, url, '#Discover #Music #AI'].filter(Boolean).join('\n\n');
return [{ json: { tweet_text, video_url: url, content_id: best.contentId, title: best.title, relevancy_score: best.score } }];
