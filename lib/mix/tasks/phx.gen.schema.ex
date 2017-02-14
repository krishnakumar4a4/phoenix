Code.require_file("../../../installer/lib/phx_new/generator.ex", __DIR__)

defmodule Mix.Tasks.Phx.Gen.Schema do
  @shortdoc "Generates an Ecto Schema"

  @moduledoc """
  Generates an Ecto schema and migration.

      mix phx.gen.schema Blog.Post blog_posts title:string views:integer

  The first argument is the module name followed by its plural
  name (used for the schema).

  The generated schema above will contain:

    * a schema file in lib/blog/post.ex, with a `blog_posts` table.
    * a migration file for the repository

  The generated migration can be skipped with `--no-migration`.

  ## Attributes

  The resource fields are given using `name:type` syntax
  where type are the types supported by Ecto. Omitting
  the type makes it default to `:string`:

      mix phx.gen.schema Blog.Post blog_posts title views:integer

  The generator also supports `belongs_to` associations
  via references:

      mix phx.gen.schema Blog.Post blog_posts title user_id:references:users

  This will result in a migration with an `:integer` column
  of `:user_id` and create an index. It will also generate
  the appropriate `belongs_to` entry in the schema.

  Furthermore an array type can also be given if it is
  supported by your database, although it requires the
  type of the underlying array element to be given too:

      mix phx.gen.schema Blog.Post blog_posts tags:array:string

  Unique columns can be automatically generated by using:

      mix phx.gen.schema Blog.Post blog_posts title:unique unique_int:integer:unique

  If no data type is given, it defaults to a string.

  ## table

  By default, the table name for the migration and schema will be
  the plural name provided for the resource. To customize this value,
  a `--table` option may be provided. For exampe:

      mix phx.gen.schema Blog.Post posts --table cms_posts

  ## binary_id

  Generated migration can use `binary_id` for schema's primary key
  and its references with option `--binary-id`.

  This option assumes the project was generated with the `--binary-id`
  option, that sets up schemas to use `binary_id` by default. If that's
  not the case you can still set all your schemas to use `binary_id`
  by default, by adding the following to your `schema` function in
  `lib/web.ex` or before the `schema` declaration:

      @primary_key {:id, :binary_id, autogenerate: true}
      @foreign_key_type :binary_id

  ## Default options

  This generator uses default options provided in the `:generators`
  configuration of the `:phoenix` application. These are the defaults:

      config :phoenix, :generators,
        migration: true,
        binary_id: false,
        sample_binary_id: "11111111-1111-1111-1111-111111111111"

  You can override those options per invocation by providing corresponding
  switches, e.g. `--no-binary-id` to use normal ids despite the default
  configuration or `--migration` to force generation of the migration.
  """
  use Mix.Task

  alias Mix.Phoenix.Schema

  @switches [migration: :boolean, binary_id: :boolean, table: :string]

  def run(args) do
    schema = build(args)
    paths = Mix.Phoenix.generator_paths()

    schema
    |> copy_new_files(paths, schema: schema)
    |> print_shell_instructions()
  end

  def build(args, help \\ __MODULE__) do
    unless Phx.New.Generator.in_single?(File.cwd!()) do
      Mix.raise "mix phx.gen.schema can only be run inside an application directory"
    end
    {opts, parsed, _} = OptionParser.parse(args, switches: @switches)
    [schema_name, plural | attrs] = validate_args!(parsed, help)

    schema = Schema.new(schema_name, plural, attrs, opts)
    Mix.Phoenix.check_module_name_availability!(schema.module)

    schema
  end

  def copy_new_files(%Schema{} = schema, paths, binding) do
    Mix.Phoenix.copy_from paths, "priv/templates/phx.gen.html", "", binding, [
      {:eex, "schema.ex",          schema.file},
      {:eex, "migration.exs",      "priv/repo/migrations/#{timestamp()}_create_#{String.replace(schema.singular, "/", "_")}.exs"},
    ]
    schema
  end

  def print_shell_instructions(%Schema{} = schema) do
    if schema.migration? do
      Mix.shell.info """

      Remember to update your repository by running migrations:

          $ mix ecto.migrate
      """
    end
  end

  def validate_args!([schema, plural | _] = args, help) do
    unless schema =~ ~r/^[A-Z].*$/ do
      Mix.raise "expected the schema argument, #{inspect schema}, to be a valid module name"
    end
    cond do
      String.contains?(plural, ":") ->
        help.raise_with_help()
      plural != Phoenix.Naming.underscore(plural) ->
        Mix.raise "expected the plural argument, #{inspect plural}, to be all lowercase using snake_case convention"
      true ->
        args
    end
  end
  def validate_args!(_, help) do
    help.raise_with_help()
  end

  @spec raise_with_help() :: no_return()
  def raise_with_help do
    Mix.raise """
    mix phx.gen.schema expects both singular and plural names
    of the generated resource followed by any number of attributes:

        mix phx.gen.schema Blog.Post blog_posts title:string
    """
  end

  defp timestamp do
    {{y, m, d}, {hh, mm, ss}} = :calendar.universal_time()
    "#{y}#{pad(m)}#{pad(d)}#{pad(hh)}#{pad(mm)}#{pad(ss)}"
  end
  defp pad(i) when i < 10, do: << ?0, ?0 + i >>
  defp pad(i), do: to_string(i)
end
