defmodule LedgerWeb.ErrorView do
  use LedgerWeb, :view

  # If you want to customize a particular status code
  # for a certain format, you may uncomment below.
  # def render("500.json", _assigns) do
  #   %{errors: %{detail: "Internal Server Error"}}
  # end

  def render("changeset_error.json", %{changeset: changeset = %Ecto.Changeset{}}) do
    errors =
      Ecto.Changeset.traverse_errors(changeset, fn
        {"is invalid",
         [type: {:parameterized, Ecto.Enum, %{mappings: mappings}}, validation: :cast]} ->
          valid_values = Keyword.values(mappings)
          "is invalid -- must be one of (#{Enum.join(valid_values, ", ")})"

        {message, opts} ->
          message
      end)

    %{errors: errors}
  end

  # By default, Phoenix returns the status message from
  # the template name. For example, "404.json" becomes
  # "Not Found".
  def template_not_found(template, _assigns) do
    %{errors: %{detail: Phoenix.Controller.status_message_from_template(template)}}
  end
end
