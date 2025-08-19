defmodule PolylineTest do
  use ExUnit.Case
  use ExUnitProperties

  doctest Polyline

  @example [
    %{longitude: -120.2, latitude: 38.5},
    %{longitude: -120.95, latitude: 40.7},
    %{longitude: -126.453, latitude: 43.252}
  ]

  @example_slashes [
    %{longitude: -82.55, latitude: 35.6},
    %{longitude: -82.55015, latitude: 35.59985},
    %{longitude: -82.55, latitude: 35.6}
  ]

  test "encode an empty List" do
    assert Polyline.encode([]) == ""
  end

  test "encode a single location" do
    assert Polyline.encode([{-120.2, 38.5}]) == "_p~iF~ps|U"
  end

  test "encode a List of lon/lat pairs into an String" do
    assert Polyline.encode(@example) == "_p~iF~ps|U_ulLnnqC_mqNvxq`@"
  end

  test "encode a List of lon/lat pairs into an String with custom precision" do
    assert Polyline.encode(@example, 6) == "_izlhA~rlgdF_{geC~ywl@_kwzCn`{nI"
  end

  test "decode an empty List" do
    assert Polyline.decode("") == []
  end

  test "decode a single location" do
    assert Polyline.decode("_p~iF~ps|U") == [%{longitude: -120.2, latitude: 38.5}]
  end

  test "decode a String into a List of lon/lat pairs" do
    assert Polyline.decode("_p~iF~ps|U_ulLnnqC_mqNvxq`@") == @example
  end

  test "decode a String into a List of lon/lat pairs with custom precision" do
    assert Polyline.decode("_izlhA~rlgdF_{geC~ywl@_kwzCn`{nI", 6) == @example
  end

  test "encode -> decode" do
    assert @example_slashes |> Polyline.encode() |> Polyline.decode() == @example_slashes
  end

  test "decode -> encode" do
    assert "_chxEn`zvN\\\\]]" |> Polyline.decode() |> Polyline.encode() == "_chxEn`zvN\\\\]]"
  end

  test "decode a long string to Geometry" do
    res =
      [".", "test", "fixtures", "long.polyline.txt"]
      |> Path.join()
      |> File.read!()
      |> String.trim()
      |> Polyline.decode()
      |> Enum.map(fn %{longitude: lon, latitude: lat} -> {lon, lat} end)

    expected =
      [".", "test", "fixtures", "long.geo.json"]
      |> Path.join()
      |> File.read!()
      |> String.trim()

    assert %Geo.LineString{coordinates: res}
           |> Geo.JSON.encode!()
           |> Poison.encode!() == expected
  end

  test "encode an over-precise string same way as reference implementation" do
    assert Polyline.encode([
             {-87.650933, 41.875332},
             {-87.650936, 41.875336},
             {-87.650942, 41.875340}
           ]) == "ywq~Fhi~uOA@??"
  end

  test "encode a long string" do
    res =
      [".", "test", "fixtures", "long.geo.json"]
      |> Path.join()
      |> File.read!()
      |> Poison.decode!()
      |> Geo.JSON.decode!()
      |> Map.get(:coordinates)
      |> Polyline.encode()

    expected =
      [".", "test", "fixtures", "long.polyline.txt"]
      |> Path.join()
      |> File.read!()
      |> String.trim()

    assert res == expected
  end

  test "identity with a long string to Geometry" do
    polyline =
      [".", "test", "fixtures", "long.polyline.txt"]
      |> Path.join()
      |> File.read!()
      |> String.trim()

    assert polyline |> Polyline.decode() |> Polyline.encode() == polyline
  end

  test "identity with 0,0 point" do
    polyline = "??"
    assert polyline |> Polyline.decode() |> Polyline.encode() == polyline
  end

  test "discard leftover elements when decoding" do
    string =
      "i|~wAeo{aVw@i@SI]EkN^c@@KfXGNULcCo@}HgByEkAcFcAsCk@oAYeAYgZuGiBu@wCi@iGo@eKBiHx@aGzAeMpEgJ`Dy@wC~@kK|D_A`@yLlEkAXuJhDuAj@yAp@mKzD{h@bRu@NcIpCmIbDmGxBk@RkD`AgBj@wAf@a@mBe@sCiCiNkCcMgCkMeBZWE}@BmKsAkCWwE]{BGyC?iBD}BJwCVgDb@mByNu@wSGaC{DL"

    assert string |> Polyline.decode() |> Enum.count() == 64
  end

  property "encoding/decoding returns approximately the same points" do
    check all(points <- point_list()) do
      encoded = Polyline.encode(points)
      decoded = Polyline.decode(encoded)
      assert length(decoded) == length(points)

      for {expected, actual} <- Enum.zip(points, decoded) do
        assert_approx_equal_points(expected, actual)
      end
    end
  end

  test "encode accepts a list of {lon,lat} tuples" do
    tuples = [{-120.2, 38.5}, {-120.95, 40.7}, {-126.453, 43.252}]
    assert Polyline.encode(tuples) == "_p~iF~ps|U_ulLnnqC_mqNvxq`@"
  end

  test "encode accepts a list of %{longitude, latitude} maps" do
    assert Polyline.encode(@example) == "_p~iF~ps|U_ulLnnqC_mqNvxq`@"
  end

  test "encode accepts a list of %{lon, lat} maps" do
    coords = [
      %{lon: -120.2, lat: 38.5},
      %{lon: -120.95, lat: 40.7},
      %{lon: -126.453, lat: 43.252}
    ]

    assert Polyline.encode(coords) == "_p~iF~ps|U_ulLnnqC_mqNvxq`@"
  end

  test "encode accepts a list of Geo.Point structs" do
    points = [
      %Geo.Point{coordinates: {-120.2, 38.5}},
      %Geo.Point{coordinates: {-120.95, 40.7}},
      %Geo.Point{coordinates: {-126.453, 43.252}}
    ]

    assert Polyline.encode(points) == "_p~iF~ps|U_ulLnnqC_mqNvxq`@"
  end

  test "encode accepts a mixed list of tuples, maps, and Geo.Point" do
    mixed = [
      {-120.2, 38.5},
      %{longitude: -120.95, latitude: 40.7},
      %Geo.Point{coordinates: {-126.453, 43.252}}
    ]

    assert Polyline.encode(mixed) == "_p~iF~ps|U_ulLnnqC_mqNvxq`@"
  end

  test "encode with custom precision from %{longitude, latitude} maps" do
    assert Polyline.encode(@example, 6) == "_izlhA~rlgdF_{geC~ywl@_kwzCn`{nI"
  end

  test "decode then encode returns the same string" do
    poly = "_chxEn`zvN\\\\]]"
    assert poly |> Polyline.decode() |> Polyline.encode() == poly
  end

  test "encode a single location map" do
    assert Polyline.encode([%{longitude: -120.2, latitude: 38.5}]) == "_p~iF~ps|U"
  end

  test "encode raises on unsupported input shape" do
    assert_raise ArgumentError, fn ->
      Polyline.encode([%{x: 1, y: 2}])
    end
  end

  defp coord, do: float(min: -180.0, max: 180.0)
  defp point, do: tuple({coord(), coord()})
  defp point_list, do: nonempty(list_of(point(), max_length: 10))

  defp assert_approx_equal_points(expected, actual, eps \\ 1.0e-5) do
    {expected_lon, expected_lat} = normalize_point(expected)
    {actual_lon, actual_lat} = normalize_point(actual)

    assert_in_delta expected_lon, actual_lon, eps
    assert_in_delta expected_lat, actual_lat, eps
  end

  defp normalize_point({lon, lat}), do: {lon, lat}
  defp normalize_point(%{lon: lon, lat: lat}), do: {lon, lat}
  defp normalize_point(%{longitude: lon, latitude: lat}), do: {lon, lat}
  defp normalize_point(%Geo.Point{coordinates: {lon, lat}}), do: {lon, lat}
end
