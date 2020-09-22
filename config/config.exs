# This file is responsible for configuring your application
# and its dependencies with the aid of the Mix.Config module.
use Mix.Config

# This configuration is loaded before any dependency and is restricted
# to this project. If another project depends on this project, this
# file won't be loaded nor affect the parent project. For this reason,
# if you want to provide default values for your application for third-
# party users, it should be done in your mix.exs file.

# Sample configuration:
#
#     config :logger, :console,
#       level: :info,
#       format: "$date $time [$level] $metadata$message\n",
#       metadata: [:user_id]

defmodule CH do
  def system_boolean(name) do
    case String.downcase(System.get_env(name) || "") do
      "true" -> true
      "yes" -> true
      "1" -> true
      "on" -> true
      _ -> false
    end
  end
end

config :plug_mint_proxy,
  author: :"mu-semtech",
  log_backend_communication: CH.system_boolean("LOG_BACKEND_COMMUNICATION"),
  log_frontend_communication: CH.system_boolean("LOG_FRONTEND_COMMUNICATION"),
  log_request_processing: CH.system_boolean("LOG_FRONTEND_PROCESSING"),
  log_response_processing: CH.system_boolean("LOG_BACKEND_PROCESSING"),
  log_connection_setup: CH.system_boolean("LOG_CONNECTION_SETUP"),
  log_request_body: CH.system_boolean("LOG_REQUEST_BODY"),
  log_response_body: CH.system_boolean("LOG_RESPONSE_BODY")

config :dispatcher,
  author: :"mu-semtech",
  # log the available layers on each call
  log_available_layers: CH.system_boolean("LOG_AVAILABLE_LAYERS"),
  # log whenever a layer starts processing
  log_layer_start_processing: CH.system_boolean("LOG_LAYER_START_PROCESSING"),
  # log whenever a layer matched, and if no matching layer was found
  log_layer_matching: CH.system_boolean("LOG_LAYER_MATCHING")

# It is also possible to import configuration files, relative to this
# directory. For example, you can emulate configuration per environment
# by uncommenting the line below and defining dev.exs, test.exs and such.
# Configuration from the imported file will override the ones defined
# here (which is why it is important to import them last).
#
#     import_config "#{Mix.env}.exs"
