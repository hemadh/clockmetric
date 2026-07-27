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
              "Only administrators can cancel invitations.",
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
              "You can only cancel invitations in your own workspace.",
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
  "id, email, workspace_id, status, auth_user_id, accepted_at, revoked_at",
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

   const {
  error: deleteInvitationError,
} = await adminClient
  .from("pending_employees")
  .delete()
  .eq("id", invitation.id)
  .eq("workspace_id", workspaceId);

if (deleteInvitationError) {
  console.error(
    "Invitation deletion error:",
    deleteInvitationError,
  );

  return jsonResponse(
    {
      error:
          "The invitation could not be cancelled.",
    },
    500,
  );
}
    const invitedUserId =
        invitation.auth_user_id?.toString() ?? "";

    let authUserDeleted = false;

    if (invitedUserId) {
      const {
        data: existingProfile,
      } = await adminClient
        .from("profiles")
        .select("id")
        .eq("id", invitedUserId)
        .maybeSingle();

      if (!existingProfile) {
        const {
          error: deleteUserError,
        } = await adminClient.auth.admin.deleteUser(
          invitedUserId,
        );

        if (deleteUserError) {
          console.error(
            "Invited Auth user deletion error:",
            deleteUserError,
          );
        } else {
          authUserDeleted = true;
        }
      }
    }

    return jsonResponse(
      {
        success: true,
        message:
            "Invitation cancelled successfully.",
        auth_user_deleted: authUserDeleted,
      },
      200,
    );
  } catch (error) {
    console.error(
      "Cancel workspace invitation error:",
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