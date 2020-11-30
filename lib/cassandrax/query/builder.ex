defmodule Cassandrax.Query.Builder do
  @moduledoc """
  Builds query clauses and adds them to a `Cassandrax.Query`
  """

  @doc """
  Converts the given `data` into a query clause and adds it to the given `Cassandrax.Query`.
  """
  def build(type, queryable, {:^, _, [var]}) do
    quote do
      fragment = Cassandrax.Query.Builder.build_fragment(unquote(type), unquote(var))
      query = Cassandrax.Queryable.to_query(unquote(queryable))
      Cassandrax.Query.Builder.add_fragment(unquote(type), fragment, query)
    end
  end

  def build(type, queryable, value) do
    fragment = build_fragment(type, value)

    quote do
      query = Cassandrax.Queryable.to_query(unquote(queryable))
      Cassandrax.Query.Builder.add_fragment(unquote(type), unquote(fragment), query)
    end
  end

  # TODO fix DSL so contains and contains_key work without having to define a custom where function
  @allowed_operators [
    :==,
    :!=,
    :>,
    :<,
    :>=,
    :<=,
    :in
    # :contains,
    # :contains_key
  ]

  def build_fragment(:where, {operator, _, [field, value]}) when operator in @allowed_operators,
    do: [field, operator, value]

  # @allowed_infix_operators [
  #   :==,
  #   :!=,
  #   :>,
  #   :<,
  #   :>=,
  #   :<=,
  #   :in
  # ]

  # @allowed_bare_operators [
  #   :contains,
  #   :contains_key
  # ]

  # defp translate_bare_operator(:contains), do: "CONTAINS"
  # defp translate_bare_operator(:contains_key), do: "CONTAINS KEY"

  # def build_fragment(:where, {operator, _, [field, value]}) when operator in @allowed_infix_operators,
  #   do: [field, operator, value]

  # def build_fragment(:where, {field, _, [{operator, _, [value]}]}) when operator in @allowed_bare_operators,
  #   do: [field, translate_bare_operator(operator), value]

  def build_fragment(:where, [{field, value}]) when is_list(value), do: [field, :in, value]
  def build_fragment(:where, [{field, value}]), do: [field, :==, value]
  def build_fragment(_type, value), do: value

  def add_fragment(:where, filter, query) do
    %{query | wheres: [filter | query.wheres]}
  end

  def add_fragment(type, value, query), do: %{query | type => value}
end
