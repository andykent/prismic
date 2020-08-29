defmodule PrismicTest do
  use ExUnit.Case
  doctest Prismic

  test "greets the world" do
    assert Prismic.hello() == :world
  end
end
