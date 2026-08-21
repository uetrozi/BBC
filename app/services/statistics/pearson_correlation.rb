# frozen_string_literal: true

module Statistics
  class PearsonCorrelation
    def self.call(xs:, ys:)
      new(xs: xs, ys: ys).call
    end

    def initialize(xs:, ys:)
      @xs = xs
      @ys = ys
    end

    def call
      return nil unless valid_input?

      mean_x = mean(@xs)
      mean_y = mean(@ys)

      centered_pairs = @xs.zip(@ys).map { |x, y| [ x - mean_x, y - mean_y ] }
      variance_x = centered_pairs.sum { |centered_x, _| centered_x**2 }
      variance_y = centered_pairs.sum { |_, centered_y| centered_y**2 }
      return nil if variance_x.zero? || variance_y.zero?

      covariance = centered_pairs.sum { |centered_x, centered_y| centered_x * centered_y }
      coefficient = covariance / Math.sqrt(variance_x * variance_y)

      coefficient.clamp(-1.0, 1.0)
    end

    private

    def valid_input?
      @xs.size == @ys.size && @xs.size >= 2
    end

    def mean(values)
      values.sum.to_f / values.size
    end
  end
end
