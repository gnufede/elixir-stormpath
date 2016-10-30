defmodule StormpathWrapper do
  use Application
  use HTTPoison.Base

  @base_url "https://api.stormpath.com/v1/"
  @tenants_url @base_url <> "tenants/current"

  # See http://elixir-lang.org/docs/stable/elixir/Application.html
  # for more information on OTP Applications
  def start(_type, _args) do
    import Supervisor.Spec, warn: false

    # Define workers and child supervisors to be supervised
    children = [
      # Starts a worker by calling: StormpathWrapper.Worker.start_link(arg1, arg2, arg3)
      # worker(StormpathWrapper.Worker, [arg1, arg2, arg3]),
    ]

    # See http://elixir-lang.org/docs/stable/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: StormpathWrapper.Supervisor]
    Supervisor.start_link(children, opts)
  end

  @doc """
  Converts the binary keys in our response to strings.
  Args:
  * body - string binary response
  Returns Record or ArgumentError
  """
  def process_response_body("") do "" end
  def process_response_body(body) do JSX.decode!(body) end

  @doc """
  Boilerplate code to make POST requests.
  Args:
  * endpoint - string requested API endpoint
  * body - request body
  Returns dict
  """
  def post_request(endpoint, body) do
    StormpathWrapper.post!(endpoint, body, headers())
  end

  @doc """
  Boilerplate code to make GET requests.
  Args:
  * endpoint - string requested API endpoint
  * body - request body
  Returns dict
  """
  def get_request(endpoint) do
    StormpathWrapper.get!(endpoint, headers())
  end

  def headers do
    [ {"content-type", "application/json"},
      {"Authorization", "Basic " <> :base64.encode(key_id() <> ":" <> key_secret())}
    ]
  end

  @doc """
  Gets the api key from :stormpath, :key_id application env or
  SP_API_KEY_ID from system ENV
  Returns binary
  """
  def key_id do
    Application.get_env(:stormpath, :key_id) ||
      System.get_env("SP_API_KEY_ID")
  end

  @doc """
  Gets the api key from :stormpath, :key_secret application env or
  SP_API_KEY_SECRET from system ENV
  Returns binary
  """
  def key_secret do
    Application.get_env(:stormpath, :key_secret) ||
      System.get_env("SP_API_KEY_SECRET")
  end

  def get_tenant do
    get_request(@tenants_url).headers
    |> Enum.map(fn({k, v}) -> {String.to_atom(k), v} end)
    |> Keyword.get(:Location)
  end

  def get_application(nil) do
    get_request(get_tenant <> "/applications")
  end

  def get_application(application) do
    get_request(get_tenant <> "/applications?name=" <> application)
  end

  def get_application_href(info, application \\ nil) do
      get_application(application).body
      |> Map.get("items")
      |> List.first
      |> Map.get(info)
      |> Map.get("href")
  end

  def create_account(givenName, surname, username, email, password, application \\ nil) do
    get_application_href("accounts", application)
    |> post_request(
        JSX.encode! [
          givenName: givenName,
          surname: surname,
          username: username,
          email: email,
          password: password
        ]
      )
  end

  def login(username, password, application \\ nil) do
    get_application_href("loginAttempts", application)
    |> post_request(
      JSX.encode! [
        type: "basic",
        value: username <>":"<> password |> :base64.encode
      ]
    )
  end

  def user_info(username, password, application \\ nil) do
    login(username, password, application).body
    |> Map.get("account")
    |> Map.get("href")
    |> get_request
  end


end
