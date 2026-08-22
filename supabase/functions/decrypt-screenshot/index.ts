import { createClient } from 'npm:@supabase/supabase-js@2'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers':
    'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
}

const textEncoder = new TextEncoder()

function jsonResponse(
  body: Record<string, unknown>,
  status = 200,
): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      ...corsHeaders,
      'Content-Type': 'application/json',
    },
  })
}

Deno.serve(async (req: Request) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', {
      headers: corsHeaders,
    })
  }

  if (req.method !== 'POST') {
    return jsonResponse(
      {
        error: 'Method not allowed',
      },
      405,
    )
  }

  try {
    const authorization =
      req.headers.get('Authorization')

    if (!authorization?.startsWith('Bearer ')) {
      return jsonResponse(
        {
          error: 'Missing authorization',
        },
        401,
      )
    }

    const supabaseUrl =
      Deno.env.get('SUPABASE_URL')

    const anonKey =
      Deno.env.get('SUPABASE_ANON_KEY')

    const serviceRoleKey =
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')

    const encryptionKey =
      Deno.env.get('SCREENSHOT_AES_KEY')

    const encryptionIv =
      Deno.env.get('SCREENSHOT_AES_IV')

    if (
      !supabaseUrl ||
      !anonKey ||
      !serviceRoleKey ||
      !encryptionKey ||
      !encryptionIv
    ) {
      console.error(
        'Required function secrets are missing',
      )

      return jsonResponse(
        {
          error: 'Server configuration error',
        },
        500,
      )
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
        auth: {
          persistSession: false,
          autoRefreshToken: false,
        },
      },
    )

    const token =
      authorization.replace('Bearer ', '')

    const {
      data: { user },
      error: userError,
    } = await userClient.auth.getUser(token)

    if (userError || !user) {
      console.error(
        'Unable to validate user session:',
        JSON.stringify({
          message: userError?.message,
          status: userError?.status,
        }),
      )

      return jsonResponse(
        {
          error: 'Invalid session',
        },
        401,
      )
    }

    const body =
      await req.json().catch(() => null)

    const screenshotId =
      typeof body?.screenshot_id === 'string'
        ? body.screenshot_id.trim()
        : ''

    if (!screenshotId) {
      return jsonResponse(
        {
          error: 'screenshot_id is required',
        },
        400,
      )
    }

    const adminClient = createClient(
      supabaseUrl,
      serviceRoleKey,
      {
        auth: {
          persistSession: false,
          autoRefreshToken: false,
        },
      },
    )

    const {
      data: profile,
      error: profileError,
    } = await adminClient
      .from('profiles')
      .select(
        'id, role, workspace_id, approval_status, is_active',
      )
      .eq('id', user.id)
      .maybeSingle()

    if (profileError || !profile) {
      console.error(
        'Profile lookup failed:',
        JSON.stringify({
          userId: user.id,
          message: profileError?.message,
          details: profileError?.details,
          hint: profileError?.hint,
          code: profileError?.code,
        }),
      )

      return jsonResponse(
        {
          error: 'Profile not found',
        },
        403,
      )
    }

    if (
      profile.approval_status !== 'approved' ||
      profile.is_active !== true
    ) {
      return jsonResponse(
        {
          error: 'Account is not active',
        },
        403,
      )
    }

    const {
      data: screenshot,
      error: screenshotError,
    } = await adminClient
      .from('screenshots')
      .select(
        'id, employee_id, workspace_id, secure_image_path',
      )
      .eq('id', screenshotId)
      .maybeSingle()

    if (screenshotError || !screenshot) {
      console.error(
        'Screenshot lookup failed:',
        JSON.stringify({
          screenshotId,
          message: screenshotError?.message,
          details: screenshotError?.details,
          hint: screenshotError?.hint,
          code: screenshotError?.code,
        }),
      )

      return jsonResponse(
        {
          error: 'Screenshot not found',
        },
        404,
      )
    }

    const role =
      String(profile.role ?? '')
        .trim()
        .toLowerCase()

    const sameWorkspace =
      String(profile.workspace_id) ===
      String(screenshot.workspace_id)

    const isOwner =
      String(screenshot.employee_id) ===
      String(user.id)

    const authorized =
      sameWorkspace &&
      (
        role === 'admin' ||
        isOwner
      )

    if (!authorized) {
      console.error(
        'Screenshot authorization failed:',
        JSON.stringify({
          userId: user.id,
          role,
          profileWorkspaceId:
            profile.workspace_id,
          screenshotWorkspaceId:
            screenshot.workspace_id,
          screenshotEmployeeId:
            screenshot.employee_id,
        }),
      )

      return jsonResponse(
        {
          error: 'Not authorized',
        },
        403,
      )
    }

    const storagePath =
      String(
        screenshot.secure_image_path ?? '',
      ).trim()

    if (!storagePath) {
      return jsonResponse(
        {
          error: 'Screenshot path is missing',
        },
        404,
      )
    }

    console.log(
      'Downloading screenshot:',
      JSON.stringify({
        screenshotId,
        bucket: 'employee-screenshots',
        storagePath,
      }),
    )

    const {
      data: encryptedBlob,
      error: downloadError,
    } = await adminClient.storage
      .from('employee-screenshots')
      .download(storagePath)

    if (downloadError || !encryptedBlob) {
      console.error(
        'Storage download failed:',
        JSON.stringify({
          screenshotId,
          bucket: 'employee-screenshots',
          storagePath,
          downloadError: downloadError
            ? {
                message: downloadError.message,
                statusCode:
                  'statusCode' in downloadError
                    ? downloadError.statusCode
                    : null,
                error:
                  'error' in downloadError
                    ? downloadError.error
                    : null,
              }
            : null,
          blobReturned:
            encryptedBlob != null,
        }),
      )

      return jsonResponse(
        {
          error: 'Screenshot file unavailable',
          path: storagePath,
          storage_message:
            downloadError?.message ??
            'No file returned',
        },
        404,
      )
    }

    const keyBytes =
      textEncoder.encode(encryptionKey)

    const ivBytes =
      textEncoder.encode(encryptionIv)

    if (keyBytes.byteLength !== 32) {
      console.error(
        'SCREENSHOT_AES_KEY must be exactly 32 UTF-8 bytes',
      )

      return jsonResponse(
        {
          error: 'Invalid server encryption key',
        },
        500,
      )
    }

    if (ivBytes.byteLength !== 16) {
      console.error(
        'SCREENSHOT_AES_IV must be exactly 16 UTF-8 bytes',
      )

      return jsonResponse(
        {
          error: 'Invalid server encryption IV',
        },
        500,
      )
    }

    const cryptoKey =
      await crypto.subtle.importKey(
        'raw',
        keyBytes,
        {
          name: 'AES-CBC',
        },
        false,
        ['decrypt'],
      )

    const encryptedBytes =
      await encryptedBlob.arrayBuffer()

    const decryptedBytes =
      await crypto.subtle.decrypt(
        {
          name: 'AES-CBC',
          iv: ivBytes,
        },
        cryptoKey,
        encryptedBytes,
      )

    console.log(
      'Screenshot decrypted successfully:',
      JSON.stringify({
        screenshotId,
        storagePath,
        encryptedSize:
          encryptedBytes.byteLength,
        decryptedSize:
          decryptedBytes.byteLength,
      }),
    )

    return new Response(
      decryptedBytes,
      {
        status: 200,
        headers: {
          ...corsHeaders,
          'Content-Type': 'image/png',
          'Cache-Control':
            'private, no-store',
        },
      },
    )
  } catch (error) {
    console.error(
      'decrypt-screenshot failed:',
      JSON.stringify({
        message:
          error instanceof Error
            ? error.message
            : String(error),
        name:
          error instanceof Error
            ? error.name
            : 'UnknownError',
        stack:
          error instanceof Error
            ? error.stack
            : null,
      }),
    )

    return jsonResponse(
      {
        error:
          'Unable to decrypt screenshot',
      },
      500,
    )
  }
})