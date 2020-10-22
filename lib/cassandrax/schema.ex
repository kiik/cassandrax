defmodule Cassandrax.Schema do
  @moduledoc """
  Defines a schema in a NoSQL database.

  A NoSQL.Schema defines the schema for a table that stores data modeled after a query. This means
  the structure of the information is directly related to the query you will perform.
  """

  @doc """
  This is invoked when a query is being prepared
  """
  @callback query_statement(operation :: atom()) :: String.t()

  defmacro __using__(_opts) do
    quote do
      # First we import the Schema macroes
      import Cassandrax.Schema

      # Use Ecto.Schema to leverage the struct and other helpers
      use Ecto.Schema
      @behaviour Cassandrax.Schema

      # Include the custom types available in CassandraDB, but not mapped by Ecto.Schema
      alias Cassandrax.Schema.MapSetType

      Module.register_attribute(__MODULE__, :partition_key, accumulate: true)
    end
  end

  @doc """
  Defines an embedded schema for the Cassandra table with the given field definitions.
  """
  defmacro no_sql_schema(source, do: block) do
    quote do
      pk = @primary_key

      if !pk or pk == [],
        do: raise("You must define a @primary_key before the schema definition")

      # Set it to false to bypass Ecto primary_key verification
      @primary_key false

      [partition_keys | clustering_keys] = pk

      # This allows Users to set the partition key as an atom or as a list
      partition_keys = List.flatten([partition_keys])

      # Set ecto_primary_keys to gain the helper function __schema__(:primary_key)
      for key <- pk, do: Module.put_attribute(__MODULE__, :ecto_primary_keys, key)

      # Use Ecto's schema to leverage field definitions and metadata
      schema(unquote(source), do: unquote(block))

      # This fetches the defined fields within the schema
      schema_fields = Keyword.keys(@changeset_fields)

      for partition_key <- partition_keys do
        if partition_key not in schema_fields do
          raise ArgumentError,
                "@primary_key defines a partition key that wasn't defined in the schema: #{
                  inspect(partition_key)
                }"
        end

        Module.put_attribute(__MODULE__, :partition_key, partition_key)
      end

      if !@partition_key or @partition_key == [],
        do: raise("@primary_key cannot define an empty, nil or false partition_key")

      for clustering_key <- clustering_keys do
        if clustering_key not in schema_fields do
          raise ArgumentError,
                "@primary_key defines a clustering key that wasn't defined in the schema: #{
                  inspect(clustering_key)
                }"
        end
      end

      def parse(nil), do: nil

      def parse(data) when is_map(data) do
        sanitized_map =
          apply(__MODULE__, :__schema__, [:fields])
          |> Enum.map(fn key -> {key, Map.get(data, to_string(key))} end)
          |> Map.new()

        struct(__MODULE__, sanitized_map)
      end
    end
  end
end
