import { createClient } from "npm:@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
      "authorization, x-client-info, apikey, content-type",
};

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", {
      headers: corsHeaders,
    });
  }

  try {
    const supabaseUrl =
        Deno.env.get("SUPABASE_URL");

    const serviceRoleKey =
        Deno.env.get(
          "SUPABASE_SERVICE_ROLE_KEY",
        );

    if (!supabaseUrl || !serviceRoleKey) {
      throw new Error(
        "Supabase environment variables are missing.",
      );
    }

    const body = await req.json();

    const workspaceName =
        body.workspace_name
            ?.toString()
            .trim() ??
        "";

    const fullName =
        body.full_name
            ?.toString()
            .trim() ??
        "";

    const email =
        body.email
            ?.toString()
            .trim()
            .toLowerCase() ??
        "";

    const password =
        body.password
            ?.toString() ??
        "";

    if (!workspaceName) {
      return jsonResponse(
        {
          error:
              "Workspace name is required.",
        },
        400,
      );
    }

    if (!fullName) {
      return jsonResponse(
        {
          error:
              "Full name is required.",
        },
        400,
      );
    }

    if (
      !email ||
      !email.includes("@")
    ) {
      return jsonResponse(
        {
          error:
              "A valid email address is required.",
        },
        400,
      );
    }

    if (password.length < 8) {
      return jsonResponse(
        {
          error:
              "Password must contain at least 8 characters.",
        },
        400,
      );
    }

    const adminClient =
        createClient(
          supabaseUrl,
          serviceRoleKey,
          {
            auth: {
              autoRefreshToken: false,
              persistSession: false,
            },
          },
        );

    const {
      data: existingProfile,
      error: existingProfileError,
    } = await adminClient
      .from("profiles")
      .select("id")
      .ilike("email", email)
      .maybeSingle();

    if (existingProfileError) {
      console.error(
        "Existing profile lookup error:",
        existingProfileError,
      );

      return jsonResponse(
        {
          error:
              "Unable to verify the email address.",
        },
        500,
      );
    }

    if (existingProfile) {
      return jsonResponse(
        {
          error:
              "An account already exists with this email address.",
        },
        409,
      );
    }

    const {
      data: existingAuthUsers,
      error: listUsersError,
    } = await adminClient.auth.admin
      .listUsers({
        page: 1,
        perPage: 1000,
      });

    if (listUsersError) {
      console.error(
        "Auth user lookup error:",
        listUsersError,
      );

      return jsonResponse(
        {
          error:
              "Unable to verify the account.",
        },
        500,
      );
    }

    const existingAuthUser =
        existingAuthUsers.users.find(
          (user) =>
              user.email
                  ?.trim()
                  .toLowerCase() ===
              email,
        );

    if (existingAuthUser) {
      return jsonResponse(
        {
          error:
              "An account already exists with this email address.",
        },
        409,
      );
    }

    const {
      data: authData,
      error: authError,
    } = await adminClient.auth.admin
      .createUser({
        email,
        password,
        email_confirm: true,
        user_metadata: {
          full_name: fullName,
          role: "admin",
        },
      });

    if (
      authError ||
      !authData.user
    ) {
      console.error(
        "Admin user creation error:",
        authError,
      );

      return jsonResponse(
        {
          error:
              authError?.message ??
              "The administrator account could not be created.",
        },
        400,
      );
    }

    const userId =
        authData.user.id;

    let workspaceId = "";

    try {
      const {
        data: workspace,
        error: workspaceError,
      } = await adminClient
        .from("workspaces")
        .insert({
  workspace_name: workspaceName,
  owner_email: email,
  owner_name: fullName,
  invite_code_enabled: true,
  session_timeout_minutes: 60,
})
        .select(
          "id, workspace_name",
        )
        .single();

      if (
        workspaceError ||
        !workspace
      ) {
        throw new Error(
          workspaceError?.message ??
              "The workspace could not be created.",
        );
      }

      workspaceId =
          workspace.id
              .toString();

      const {
        error: profileError,
      } = await adminClient
        .from("profiles")
        .insert({
          id: userId,
          full_name: fullName,
          email,
          role: "admin",
          workspace_id:
              workspaceId,
          approval_status:
              "approved",
          is_active: true,
          required_weekly_hours:
              45,
        });

      if (profileError) {
        throw new Error(
          profileError.message,
        );
      }

      const {
        error: metadataError,
      } = await adminClient.auth.admin
        .updateUserById(
          userId,
          {
            user_metadata: {
              full_name:
                  fullName,
              role: "admin",
              workspace_id:
                  workspaceId,
              workspace_name:
                  workspaceName,
              workspace_owner:
                  true,
            },
          },
        );

      if (metadataError) {
        console.error(
          "Metadata update error:",
          metadataError,
        );
      }

      return jsonResponse(
        {
          success: true,
          message:
              "Workspace created successfully.",
          user_id: userId,
          workspace_id:
              workspaceId,
          workspace_name:
              workspaceName,
        },
        200,
      );
    } catch (error) {
      console.error(
        "Workspace setup error:",
        error,
      );

      if (workspaceId.length > 0) {
        await adminClient
          .from("workspaces")
          .delete()
          .eq("id", workspaceId);
      }

      await adminClient.auth.admin
        .deleteUser(userId);

      return jsonResponse(
        {
          error:
              error instanceof Error
                  ? error.message
                  : "The workspace could not be created.",
        },
        500,
      );
    }
  } catch (error) {
    console.error(
      "Create workspace owner error:",
      error,
    );

    return jsonResponse(
      {
        error:
            error instanceof Error
                ? error.message
                : "Unexpected server error.",
      },
      500,
    );
  }
});

function jsonResponse(
  body: Record<string, unknown>,
  status: number,
) {
  return new Response(
    JSON.stringify(body),
    {
      status,
      headers: {
        ...corsHeaders,
        "Content-Type":
            "application/json",
      },
    },
  );
}