CREATE OR REPLACE FUNCTION public.activate_pending_employee(
  invite_email text,
  workspace uuid
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $function$
DECLARE
  auth_user_id uuid;
  auth_user_email text;
  invite_record record;
BEGIN
  auth_user_id := auth.uid();

  IF auth_user_id IS NULL THEN
    RAISE EXCEPTION 'Authentication required';
  END IF;

  SELECT email
  INTO auth_user_email
  FROM auth.users
  WHERE id = auth_user_id
  LIMIT 1;

  IF auth_user_email IS NULL THEN
    RAISE EXCEPTION 'Authenticated user email not found';
  END IF;

  IF lower(trim(auth_user_email)) <> lower(trim(invite_email)) THEN
    RAISE EXCEPTION 'Invitation does not belong to signed-in user';
  END IF;

  SELECT *
  INTO invite_record
  FROM public.pending_employees
  WHERE lower(trim(email)) = lower(trim(auth_user_email))
    AND workspace_id = workspace
  LIMIT 1;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Valid workspace invitation not found';
  END IF;

  IF EXISTS (
    SELECT 1
    FROM public.profiles
    WHERE id = auth_user_id
      AND workspace_id IS NOT NULL
      AND workspace_id <> workspace
  ) THEN
    RAISE EXCEPTION 'User already belongs to another workspace';
  END IF;

  INSERT INTO public.profiles (
    id,
    full_name,
    email,
    role,
    workspace_id
  )
  VALUES (
    auth_user_id,
    invite_record.full_name,
    invite_record.email,
    invite_record.role,
    workspace
  )
  ON CONFLICT (id) DO UPDATE
  SET
    full_name = EXCLUDED.full_name,
    email = EXCLUDED.email,
    role = EXCLUDED.role,
    workspace_id = CASE
      WHEN public.profiles.workspace_id IS NULL
        THEN EXCLUDED.workspace_id
      ELSE public.profiles.workspace_id
    END;

  DELETE FROM public.pending_employees
  WHERE lower(trim(email)) = lower(trim(auth_user_email))
    AND workspace_id = workspace;
END;
$function$;

REVOKE ALL
ON FUNCTION public.activate_pending_employee(text, uuid)
FROM PUBLIC;

REVOKE ALL
ON FUNCTION public.activate_pending_employee(text, uuid)
FROM anon;

GRANT EXECUTE
ON FUNCTION public.activate_pending_employee(text, uuid)
TO authenticated;
