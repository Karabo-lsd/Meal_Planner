import { createClient } from "npm:@supabase/supabase-js@2";

type Json = Record<string, unknown>;

type AnalyzePayload = {
  user_id?: string;
  filename?: string;
  image_base64?: string;
};

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

const stopWords = new Set([
  "img",
  "image",
  "photo",
  "meal",
  "food",
  "scan",
  "camera",
  "upload",
  "jpg",
  "jpeg",
  "png",
  "heic",
]);

function extractSearchTokens(filename?: string): string[] {
  if (!filename) return [];

  const noExt = filename.replace(/\.[a-z0-9]+$/i, "").toLowerCase();
  const parts = noExt
    .split(/[^a-z0-9]+/)
    .map((p) => p.trim())
    .filter((p) => p.length >= 3 && !stopWords.has(p));

  return Array.from(new Set(parts));
}

function asNumber(value: unknown): number {
  if (typeof value === "number") return value;
  if (typeof value === "string") {
    const parsed = Number(value);
    return Number.isFinite(parsed) ? parsed : 0;
  }
  return 0;
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const { filename } = (await req.json()) as AnalyzePayload;

    const supabaseUrl = Deno.env.get("SUPABASE_URL");
    const supabaseAnonKey = Deno.env.get("SUPABASE_ANON_KEY");
    if (!supabaseUrl || !supabaseAnonKey) {
      return new Response(
        JSON.stringify({ error: "Missing SUPABASE_URL or SUPABASE_ANON_KEY." }),
        {
          status: 500,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        },
      );
    }

    const authHeader = req.headers.get("Authorization") ?? "";
    const supabase = createClient(supabaseUrl, supabaseAnonKey, {
      global: {
        headers: {
          Authorization: authHeader,
        },
      },
    });

    const tokens = extractSearchTokens(filename);

    for (const token of tokens.slice(0, 5)) {
      const { data, error } = await supabase
        .from("foods_master")
        .select("id, canonical_name, food_nutrition(per_100g_calories, per_100g_protein, per_100g_carbs, per_100g_fat)")
        .ilike("canonical_name", `%${token}%`)
        .limit(1);

      if (error) {
        console.error("foods_master query failed", error);
        continue;
      }

      const rows = (data ?? []) as Json[];
      if (rows.length === 0) continue;

      const food = rows[0];
      const nutritionRaw = food.food_nutrition;
      const nutrition = Array.isArray(nutritionRaw)
        ? ((nutritionRaw[0] as Json | undefined) ?? {})
        : ((nutritionRaw as Json | undefined) ?? {});

      const response = {
        meal_title: String(food.canonical_name ?? "Scanned Meal"),
        meal_type: "Meal",
        confidence: 0.62,
        canonical_food_id: String(food.id ?? ""),
        calories: Math.round(asNumber(nutrition.per_100g_calories)),
        protein: asNumber(nutrition.per_100g_protein),
        carbs: asNumber(nutrition.per_100g_carbs),
        fat: asNumber(nutrition.per_100g_fat),
        source: "supabase-edge-catalog",
      };

      return new Response(JSON.stringify(response), {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    return new Response(
      JSON.stringify({
        meal_title: "Scanned Meal",
        meal_type: "Meal",
        confidence: 0.2,
        calories: 0,
        protein: 0,
        carbs: 0,
        fat: 0,
        source: "supabase-edge-no-match",
      }),
      {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      },
    );
  } catch (error) {
    console.error("analyze-meal-image failed", error);
    return new Response(
      JSON.stringify({
        error: "Invalid request payload.",
        meal_title: "Scanned Meal",
        meal_type: "Meal",
        confidence: 0.1,
        calories: 0,
        protein: 0,
        carbs: 0,
        fat: 0,
        source: "supabase-edge-error",
      }),
      {
        status: 400,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      },
    );
  }
});
