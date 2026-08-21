require "test_helper"

class Statistics::PearsonCorrelationTest < ActiveSupport::TestCase
  test "returns 1.0 for perfect positive correlation" do
    result = Statistics::PearsonCorrelation.call(
      xs: [ 1.0, 2.0, 3.0, 4.0 ],
      ys: [ 10.0, 20.0, 30.0, 40.0 ]
    )

    assert_in_delta 1.0, result, 0.0001
  end

  test "returns -1.0 for perfect negative correlation" do
    result = Statistics::PearsonCorrelation.call(
      xs: [ 1.0, 2.0, 3.0, 4.0 ],
      ys: [ 40.0, 30.0, 20.0, 10.0 ]
    )

    assert_in_delta(-1.0, result, 0.0001)
  end

  test "returns a value near zero for uncorrelated sample" do
    result = Statistics::PearsonCorrelation.call(
      xs: [ 1.0, 2.0, 3.0, 4.0, 5.0 ],
      ys: [ 2.0, 1.0, 2.0, 1.0, 2.0 ]
    )

    assert_in_delta 0.0, result, 0.05
  end

  test "returns nil for fewer than two value pairs" do
    result = Statistics::PearsonCorrelation.call(xs: [ 1.0 ], ys: [ 5.0 ])

    assert_nil result
  end

  test "returns nil for identical x values" do
    result = Statistics::PearsonCorrelation.call(
      xs: [ 2.0, 2.0, 2.0 ],
      ys: [ 1.0, 3.0, 5.0 ]
    )

    assert_nil result
  end

  test "returns nil for identical y values" do
    result = Statistics::PearsonCorrelation.call(
      xs: [ 1.0, 3.0, 5.0 ],
      ys: [ 7.0, 7.0, 7.0 ]
    )

    assert_nil result
  end
end
