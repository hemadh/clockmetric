import { createClient } from "@supabase/supabase-js";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
      "authorization, x-client-info, apikey, content-type",
};

type ScreenshotRow = {
  id: string;
  secure_image_path: string | null;
  expires_at: string;
};

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", {
      headers: corsHeaders,
    });
  }

  try {
    const authorization = req.headers.get("Authorization");

    if (!authorization) {
      return new Response(
        JSON.stringify({
          success: false,
          error: "Authorization header is missing.",
        }),
        {
          status: 401,
          headers: {
            ...corsHeaders,
            "Content-Type": "application/json",
          },
        },
      );
    }

    const supabaseUrl = Deno.env.get("SUPABASE_URL");
    const anonKey = Deno.env.get("SUPABASE_ANON_KEY");
    const serviceRoleKey = Deno.env.get(
      "SUPABASE_SERVICE_ROLE_KEY",
    );

    if (!supabaseUrl || !anonKey || !serviceRoleKey) {
      throw new Error(
        "Required Supabase environment variables are missing.",
      );
    }

    const userClient = createClient(
      supabaseUrl,
      anonKey,
      {
        global: {
          headers: {
            Authorization: authorization,
          },
        },
      },
    );

    const {
      data: { user },
      error: userError,
    } = await userClient.auth.getUser();

    if (userError || !user) {
      return new Response(
        JSON.stringify({
          success: false,
          error: "Invalid or expired user session.",
        }),
        {
          status: 401,
          headers: {
            ...corsHeaders,
            "Content-Type": "application/json",
          },
        },
      );
    }

    const adminClient = createClient(
      supabaseUrl,
      serviceRoleKey,
      {
        auth: {
          autoRefreshToken: false,
          persistSession: false,
        },
      },
    );

    const nowIso = new Date().toISOString();

const {
  data: expiredScreenshots,
  error: fetchError,
} = await adminClient
  .from("screenshots")
  .select("id, secure_image_path, expires_at")
  .lte("expires_at", nowIso)
  .limit(500);

    if (fetchError) {
      throw fetchError;
    }

    if (
      !expiredScreenshots ||
      expiredScreenshots.length === 0
    ) {
      return new Response(
        JSON.stringify({
          success: true,
          deletedFiles: 0,
          deletedRows: 0,
          message: "No expired screenshots found.",
          cutoff: nowIso,
        }),
        {
          status: 200,
          headers: {
            ...corsHeaders,
            "Content-Type": "application/json",
          },
        },
      );
    }

    const paths = expiredScreenshots
  .map(
    (row: ScreenshotRow) =>
      row.secure_image_path?.trim(),
  )
      .filter(
        (path: string | undefined): path is string =>
          path !== undefined && path.length > 0,
      );

    if (paths.length > 0) {
      const { error: storageError } =
          await adminClient.storage
  .from("employee-screenshots")
  .remove(paths);

      if (storageError) {
        throw storageError;
      }
    }

   const ids = expiredScreenshots.map(
  (row: ScreenshotRow) => row.id,
);

    const { error: deleteError } = await adminClient
      .from("screenshots")
      .delete()
      .in("id", ids);

    if (deleteError) {
      throw deleteError;
    }

    return new Response(
      JSON.stringify({
        success: true,
        deletedFiles: paths.length,
        deletedRows: ids.length,
        cutoff: nowIso,
      }),
      {
        status: 200,
        headers: {
          ...corsHeaders,
          "Content-Type": "application/json",
        },
      },
    );
  } catch (error) {
    console.error(
      "Expired screenshot cleanup failed:",
      error,
    );

    return new Response(
      JSON.stringify({
        success: false,
        error:
          error instanceof Error
            ? error.message
            : String(error),
      }),
      {
        status: 500,
        headers: {
          ...corsHeaders,
          "Content-Type": "application/json",
        },
      },
    );
  }
});