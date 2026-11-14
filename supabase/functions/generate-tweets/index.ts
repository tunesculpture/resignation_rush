import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';
const cors = { 'Access-Control-Allow-Origin': '*', 'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type', 'Access-Control-Allow-Methods': 'POST, OPTIONS' };
Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: cors });
  try {
    const auth = req.headers.get('Authorization');
    if (!auth) return new Response(JSON.stringify({ error: 'Unauthorized' }), { status: 401, headers: { ...cors, 'Content-Type': 'application/json' } });
    const supabase = createClient(Deno.env.get('SUPABASE_URL')!, Deno.env.get('SUPABASE_ANON_KEY')!, { global: { headers: { Authorization: auth } } });
    const { data: { user }, error: userError } = await supabase.auth.getUser();
    if (userError || !user) return new Response(JSON.stringify({ error: 'Unauthorized' }), { status: 401, headers: { ...cors, 'Content-Type': 'application/json' } });
    const body = await req.json();
    const topic = String(body.topic ?? '').trim();
    const tagline = String(body.tagline ?? '').trim();
    const count = Math.min(100, Math.max(1, Number(body.count ?? 10)));
    const exclude = Array.isArray(body.exclude) ? body.exclude.slice(-150).map(String) : [];
    if (!topic) return new Response(JSON.stringify({ error: 'Topic is required' }), { status: 400, headers: { ...cors, 'Content-Type': 'application/json' } });
    const { data: settings } = await supabase.from('app_settings').select('global_system_prompt').eq('id', 1).single();
    const apiKey = Deno.env.get('AI_API_KEY');
    const endpoint = Deno.env.get('AI_API_URL') ?? 'https://generativelanguage.googleapis.com/v1beta/openai/chat/completions';
    const model = Deno.env.get('AI_MODEL') ?? 'gemini-2.5-flash';
    if (!apiKey) throw new Error('AI provider is not configured by the administrator.');
    const system = `${settings?.global_system_prompt ?? 'Write distinct, natural, medium-length tweets.'}\nReturn ONLY valid JSON: {"tweets":[...]} with exactly ${count} unique tweets. Keep tweets medium length (about 30-50 words), natural, varied in perspective and format. Include relevant hashtags and emojis naturally. Avoid duplicates of the excluded tweets. ${tagline ? `Append this exact tagline to every tweet: ${tagline}` : 'Do not add a tagline.'}`;
    const response = await fetch(endpoint, { method: 'POST', headers: { 'Authorization': `Bearer ${apiKey}`, 'Content-Type': 'application/json' }, body: JSON.stringify({ model, temperature: 0.9, response_format: { type: 'json_object' }, messages: [{ role: 'system', content: system }, { role: 'user', content: `Topic and context:\n${topic}\n\nPreviously generated tweets to avoid:\n${exclude.join('\n---\n')}` }] }) });
    const raw = await response.text();
    if (!response.ok) throw new Error(`AI provider error (${response.status}): ${raw.slice(0, 500)}`);
    const payload = JSON.parse(raw);
    const content = payload.choices?.[0]?.message?.content ?? '{}';
    const parsed = JSON.parse(content);
    const tweets = Array.isArray(parsed.tweets) ? parsed.tweets.slice(0, count).map((x: unknown) => String(x).trim()).filter(Boolean) : [];
    if (tagline) for (let i = 0; i < tweets.length; i++) if (!tweets[i].endsWith(tagline)) tweets[i] = `${tweets[i]}\n\n${tagline}`;
    return new Response(JSON.stringify({ tweets }), { headers: { ...cors, 'Content-Type': 'application/json' } });
  } catch (e) {
    return new Response(JSON.stringify({ error: e instanceof Error ? e.message : 'Generation failed' }), { status: 500, headers: { ...cors, 'Content-Type': 'application/json' } });
  }
});
