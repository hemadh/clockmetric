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
    const supabaseUrl = Deno.env.get("SUPABASE_URL");
    const anonKey = Deno.env.get("SUPABASE_ANON_KEY");
    const serviceRoleKey = Deno.env.get(
      "SUPABASE_SERVICE_ROLE_KEY",
    );

    if (!supabaseUrl || !anonKey || !serviceRoleKey) {
      throw new Error(
        "Supabase environment variables are missing.",
      );
    }

    const authorization = req.headers.get("Authorization");

    if (!authorization) {
      return jsonResponse(
        {
          error: "Authorization header is missing.",
        },
        401,
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
      data: { user: requestingUser },
      error: requestingUserError,
    } = await userClient.auth.getUser();

    if (requestingUserError || !requestingUser) {
      return jsonResponse(
        {
          error: "You must be logged in.",
        },
        401,
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

    const {
      data: requestingProfile,
      error: profileError,
    } = await adminClient
      .from("profiles")
      .select(
        "id, role, workspace_id, full_name, email",
      )
      .eq("id", requestingUser.id)
      .single();

    if (profileError || !requestingProfile) {
      return jsonResponse(
        {
          error: "Your profile could not be found.",
        },
        403,
      );
    }

    if (
      requestingProfile.role?.toLowerCase() !== "admin"
    ) {
      return jsonResponse(
        {
          error: "Only administrators can invite employees.",
        },
        403,
      );
    }

    const body = await req.json();

    const fullName =
      body.full_name?.toString().trim() ?? "";

    const email =
      body.email?.toString().trim().toLowerCase() ?? "";

    const requestedRole =
      body.role?.toString().trim().toLowerCase() ??
      "employee";

    const workspaceId =
      body.workspace_id?.toString().trim() ?? "";

    const redirectTo =
      body.redirect_to?.toString().trim() ?? "";

    const role =
      requestedRole === "admin"
        ? "admin"
        : "employee";

    if (!fullName) {
      return jsonResponse(
        {
          error: "Employee name is required.",
        },
        400,
      );
    }

    if (!email || !email.includes("@")) {
      return jsonResponse(
        {
          error: "A valid employee email is required.",
        },
        400,
      );
    }

    if (!workspaceId) {
      return jsonResponse(
        {
          error: "Workspace ID is required.",
        },
        400,
      );
    }

    if (
      requestingProfile.workspace_id !== workspaceId
    ) {
      return jsonResponse(
        {
          error:
              "You can only invite employees to your own workspace.",
        },
        403,
      );
    }

    const {
      data: existingProfile,
    } = await adminClient
      .from("profiles")
      .select("id, email, workspace_id")
      .ilike("email", email)
      .maybeSingle();

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
      data: existingInvitation,
    } = await adminClient
      .from("pending_employees")
      .select(
        "id, accepted_at, revoked_at",
      )
      .eq("workspace_id", workspaceId)
      .ilike("email", email)
      .is("accepted_at", null)
      .is("revoked_at", null)
      .maybeSingle();

    if (existingInvitation) {
      return jsonResponse(
        {
          error:
              "This employee already has a pending invitation.",
        },
        409,
      );
    }

    const inviteOptions: {
      data: Record<string, string>;
      redirectTo?: string;
    } = {
      data: {
        full_name: fullName,
        role: role,
        workspace_id: workspaceId,
        invited_by: requestingUser.id,
      },
    };

    if (redirectTo) {
      inviteOptions.redirectTo = redirectTo;
    }

    const {
      data: invitationData,
      error: invitationError,
    } = await adminClient.auth.admin
      .inviteUserByEmail(
        email,
        inviteOptions,
      );

    if (invitationError) {
      console.error(
        "Invitation email error:",
        invitationError,
      );

      return jsonResponse(
        {
          error: invitationError.message,
        },
        400,
      );
    }

    const invitedUserId =
      invitationData.user?.id ?? null;

    const {
      error: pendingInsertError,
    } = await adminClient
      .from("pending_employees")
      .insert({
        full_name: fullName,
        email: email,
        role: role,
        status: "invited",
        workspace_id: workspaceId,
        invited_by: requestingUser.id,
        auth_user_id: invitedUserId,
        invited_at: new Date().toISOString(),
        last_invited_at: new Date().toISOString(),
        invite_count: 1,
      });

    if (pendingInsertError) {
      console.error(
        "Pending invitation insert error:",
        pendingInsertError,
      );

      return jsonResponse(
        {
          success: true,
          warning:
              "Invitation email was sent, but the pending invitation record could not be saved.",
        },
        200,
      );
    }

    return jsonResponse(
      {
        success: true,
        message:
            "Invitation email sent successfully.",
        invited_user_id: invitedUserId,
      },
      200,
    );
  } catch (error) {
    console.error(
      "Invite workspace member error:",
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
        "Content-Type": "application/json",
      },
    },
  );
}