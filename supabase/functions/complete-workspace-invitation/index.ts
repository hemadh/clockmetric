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
      data: { user },
      error: userError,
    } = await userClient.auth.getUser();

    if (userError || !user || !user.email) {
      return jsonResponse(
        {
          error:
              "Your invitation session is invalid or expired.",
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

    const email = user.email.trim().toLowerCase();

    let invitation: any = null;

    const {
      data: invitationByUserId,
      error: invitationByUserIdError,
    } = await adminClient
      .from("pending_employees")
      .select(
        "id, full_name, email, role, workspace_id, status, " +
          "auth_user_id, accepted_at, revoked_at",
      )
      .eq("auth_user_id", user.id)
      .is("accepted_at", null)
      .is("revoked_at", null)
      .maybeSingle();

    if (invitationByUserIdError) {
      console.error(
        "Invitation lookup by user ID error:",
        invitationByUserIdError,
      );
    }

    invitation = invitationByUserId;

    if (!invitation) {
      const {
        data: invitationByEmail,
        error: invitationByEmailError,
      } = await adminClient
        .from("pending_employees")
        .select(
          "id, full_name, email, role, workspace_id, status, " +
            "auth_user_id, accepted_at, revoked_at",
        )
        .ilike("email", email)
        .is("accepted_at", null)
        .is("revoked_at", null)
        .maybeSingle();

      if (invitationByEmailError) {
        console.error(
          "Invitation lookup by email error:",
          invitationByEmailError,
        );
      }

      invitation = invitationByEmail;
    }

    if (!invitation) {
      return jsonResponse(
        {
          error:
              "No active workspace invitation was found.",
        },
        404,
      );
    }

    const invitedEmail =
        invitation.email?.toString().trim().toLowerCase() ??
        "";

    if (invitedEmail != email) {
      return jsonResponse(
        {
          error:
              "This invitation belongs to another email address.",
        },
        403,
      );
    }

    const workspaceId =
        invitation.workspace_id?.toString().trim() ?? "";

    if (!workspaceId) {
      return jsonResponse(
        {
          error:
              "The invitation does not contain a workspace.",
        },
        400,
      );
    }

    const fullName =
        invitation.full_name?.toString().trim() ??
        user.user_metadata?.full_name?.toString().trim() ??
        email;

    const invitedRole =
        invitation.role?.toString().trim().toLowerCase() ??
        "employee";

    const role =
        invitedRole === "admin" ? "admin" : "employee";

    const {
      data: workspace,
      error: workspaceError,
    } = await adminClient
      .from("workspaces")
      .select("id, workspace_name")
      .eq("id", workspaceId)
      .maybeSingle();

    if (workspaceError || !workspace) {
      return jsonResponse(
        {
          error:
              "The invited workspace could not be found.",
        },
        404,
      );
    }

    const {
      error: profileError,
    } = await adminClient
      .from("profiles")
      .upsert(
        {
          id: user.id,
          full_name: fullName,
          email: email,
          role: role,
          workspace_id: workspaceId,
          approval_status: "approved",
          is_active: true,
        },
        {
          onConflict: "id",
        },
      );

    if (profileError) {
      console.error(
        "Profile creation error:",
        profileError,
      );

      return jsonResponse(
        {
          error:
              "The employee profile could not be created.",
        },
        500,
      );
    }

    const now = new Date().toISOString();

    const {
      error: invitationUpdateError,
    } = await adminClient
      .from("pending_employees")
      .update({
        status: "accepted",
        accepted_at: now,
        auth_user_id: user.id,
      })
      .eq("id", invitation.id);

    if (invitationUpdateError) {
      console.error(
        "Invitation update error:",
        invitationUpdateError,
      );

      return jsonResponse(
        {
          error:
              "Your profile was created, but the invitation status could not be updated.",
        },
        500,
      );
    }

    const {
      error: metadataError,
    } = await adminClient.auth.admin.updateUserById(
      user.id,
      {
        user_metadata: {
          ...user.user_metadata,
          full_name: fullName,
          role: role,
          workspace_id: workspaceId,
          workspace_name:
              workspace.workspace_name?.toString() ?? "",
          invitation_completed: true,
        },
      },
    );

    if (metadataError) {
      console.error(
        "User metadata update error:",
        metadataError,
      );
    }

    return jsonResponse(
      {
        success: true,
        message:
            "Workspace invitation completed successfully.",
        workspace_id: workspaceId,
        workspace_name:
            workspace.workspace_name?.toString() ?? "",
      },
      200,
    );
  } catch (error) {
    console.error(
      "Complete workspace invitation error:",
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