defmodule Ledger.Cldr do
  @moduledoc """
  Unicode CLDR (Common Locale Data Repository) backend for Ledger.
  """

  use Cldr, locales: ["en"], default_locale: "en", providers: [Cldr.Currency]
end
