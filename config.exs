import Config

config :pleroma, Pleroma.Web.Endpoint,
  url: [host: System.get_env("DOMAIN", "localhost"), scheme: "https", port: 4000],
  http: [ip: {0, 0, 0, 0}, port: 4000]

config :pleroma, :instance,
  name: System.get_env("INSTANCE_NAME", "Pleroma"),
  email: System.get_env("ADMIN_EMAIL"),
  notify_email: System.get_env("NOTIFY_EMAIL"),
  limit: 5000,
  registrations_open: false,
  federating: true,
  healthcheck: true

config :pleroma, :media_proxy,
  enabled: false,
  redirect_on_failure: true,
  base_url: System.get_env("MEDIA_DOMAIN", "localhost")

config :pleroma, Pleroma.Repo,
  adapter: Ecto.Adapters.Postgres,
  username: System.get_env("DB_USER", "pleroma"),
  password: System.fetch_env!("DB_PASS"),
  database: System.get_env("DB_NAME", "pleroma"),
  hostname: System.get_env("DB_HOST", "db"),
  pool_size: 10

config :pleroma, Pleroma.Upload,
  uploader: Pleroma.Uploaders.S3,
  strip_exif: true

config :ex_aws, :s3,
  access_key_id: System.get_env("AWS_ACCESS_KEY_ID", "pleroma"),
  secret_access_key: System.get_env("AWS_SECRET_ACCESS_KEY", "pleroma"),
  region: "us-east-1",
  scheme: "https://"

# Configure web push notifications
config :web_push_encryption, :vapid_details, subject: "mailto:#{System.get_env("NOTIFY_EMAIL")}"

config :pleroma, :database, rum_enabled: false
config :pleroma, :instance, static_dir: "/var/lib/pleroma/static"

# We can't store the secrets in this file, since this is baked into the docker image
if not File.exists?("/var/lib/pleroma/secret.exs") do
  secret = :crypto.strong_rand_bytes(64) |> Base.encode64() |> binary_part(0, 64)
  signing_salt = :crypto.strong_rand_bytes(8) |> Base.encode64() |> binary_part(0, 8)
  {web_push_public_key, web_push_private_key} = :crypto.generate_key(:ecdh, :prime256v1)

  secret_file =
    EEx.eval_string(
      """
      import Config

      config :pleroma, Pleroma.Web.Endpoint,
        secret_key_base: "<%= secret %>",
        signing_salt: "<%= signing_salt %>"

      config :web_push_encryption, :vapid_details,
        public_key: "<%= web_push_public_key %>",
        private_key: "<%= web_push_private_key %>"
      """,
      secret: secret,
      signing_salt: signing_salt,
      web_push_public_key: Base.url_encode64(web_push_public_key, padding: false),
      web_push_private_key: Base.url_encode64(web_push_private_key, padding: false)
    )

  File.write("/var/lib/pleroma/secret.exs", secret_file)
end

import_config("/var/lib/pleroma/secret.exs")

# For additional user config
if File.exists?("/var/lib/pleroma/config.exs"),
  do: import_config("/var/lib/pleroma/config.exs"),
  else:
    File.write("/var/lib/pleroma/config.exs", """
    import Config

    # For additional configuration outside of environmental variables
    """)
