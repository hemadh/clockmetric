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

    const authorization =
        req.headers.get("Authorization");

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
      .select("id, role, workspace_id")
      .eq("id", requestingUser.id)
      .maybeSingle();

    if (profileError || !requestingProfile) {
      return jsonResponse(
        {
          error: "Your profile could not be found.",
        },
        403,
      );
    }

    if (
      requestingProfile.role?.toString().toLowerCase() !==
      "admin"
    ) {
      return jsonResponse(
        {
          error:
              "Only administrators can resend invitations.",
        },
        403,
      );
    }

    const body = await req.json();

    const email =
        body.email?.toString().trim().toLowerCase() ??
        "";

    const workspaceId =
        body.workspace_id?.toString().trim() ?? "";

    const redirectTo =
        body.redirect_to?.toString().trim() ??
        "timetracker://invite";

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
      requestingProfile.workspace_id?.toString() !==
      workspaceId
    ) {
      return jsonResponse(
        {
          error:
              "You can only resend invitations for your own workspace.",
        },
        403,
      );
    }

    const {
      data: invitation,
      error: invitationError,
    } = await adminClient
      .from("pending_employees")
      .select(
        "id, full_name, email, role, workspace_id, status, " +
          "auth_user_id, accepted_at, revoked_at, invite_count",
      )
      .eq("workspace_id", workspaceId)
      .ilike("email", email)
      .is("accepted_at", null)
      .is("revoked_at", null)
      .maybeSingle();

    if (invitationError) {
      console.error(
        "Invitation lookup error:",
        invitationError,
      );

      return jsonResponse(
        {
          error:
              "The pending invitation could not be checked.",
        },
        500,
      );
    }

    if (!invitation) {
      return jsonResponse(
        {
          error:
              "No active pending invitation was found.",
        },
        404,
      );
    }

    const fullName =
        invitation.full_name?.toString().trim() ??
        "Employee";

    const invitedRole =
        invitation.role?.toString().trim().toLowerCase() ??
        "employee";

    const role =
        invitedRole === "admin" ? "admin" : "employee";

    const oldAuthUserId =
        invitation.auth_user_id?.toString().trim() ?? "";

    if (oldAuthUserId) {
      const {
        data: existingProfile,
        error: existingProfileError,
      } = await adminClient
        .from("profiles")
        .select("id")
        .eq("id", oldAuthUserId)
        .maybeSingle();

      if (existingProfileError) {
        console.error(
          "Existing profile lookup error:",
          existingProfileError,
        );
      }

      if (existingProfile) {
        return jsonResponse(
          {
            error:
                "This employee has already completed registration.",
          },
          409,
        );
      }

      const {
        error: deleteOldUserError,
      } = await adminClient.auth.admin.deleteUser(
        oldAuthUserId,
      );

      if (deleteOldUserError) {
        console.error(
          "Old invited user deletion error:",
          deleteOldUserError,
        );

        return jsonResponse(
          {
            error:
                "The previous invitation could not be replaced.",
          },
          500,
        );
      }
    }

    const {
      data: invitationData,
      error: resendError,
    } = await adminClient.auth.admin.inviteUserByEmail(
      email,
      {
        redirectTo,
        data: {
          full_name: fullName,
          role,
          workspace_id: workspaceId,
          invited_by: requestingUser.id,
        },
      },
    );

    if (resendError) {
      console.error(
        "Resend invitation error:",
        resendError,
      );

      return jsonResponse(
        {
          error: resendError.message,
        },
        400,
      );
    }

    const newAuthUserId =
        invitationData.user?.id ?? null;

    const previousInviteCount =
        Number(invitation.invite_count ?? 0);

    const now = new Date().toISOString();

    const {
      error: updateError,
    } = await adminClient
      .from("pending_employees")
      .update({
        status: "invited",
        auth_user_id: newAuthUserId,
        last_invited_at: now,
        invite_count: previousInviteCount + 1,
      })
      .eq("id", invitation.id)
      .eq("workspace_id", workspaceId);

    if (updateError) {
      console.error(
        "Pending invitation update error:",
        updateError,
      );

      return jsonResponse(
        {
          success: true,
          warning:
              "The invitation email was resent, but its database record could not be updated.",
        },
        200,
      );
    }

    return jsonResponse(
      {
        success: true,
        message:
            "Invitation resent successfully.",
        invited_user_id: newAuthUserId,
      },
      200,
    );
  } catch (error) {
    console.error(
      "Resend workspace invitation error:",
      error,
    );

    return jsonResponse(
      {
        error: error instanceof Error
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