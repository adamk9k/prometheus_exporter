# frozen_string_literal: true
require_relative '../test_helper'
require 'prometheus_exporter/server'
require 'prometheus_exporter/instrumentation'
require 'prometheus_exporter/server/metrics_container'

class PrometheusMetricsContainerTest < Minitest::Test
  def stub_process_clock_time(value, &blk)
    Process.stub(:clock_gettime, value, &blk)
  end

  def metrics
    @metrics ||= PrometheusExporter::Server::MetricsContainer.new
  end

  def test_container_with_expiration
    stub_process_clock_time(1.0) do
      metrics << { key: "value" }
      assert_equal 1, metrics.size
      assert_equal 1, metrics.length
      assert_equal 61.0, metrics[0]["_expire_at"]
    end

    stub_process_clock_time(61.0) do
      metrics << { key: "value2" }
      assert_equal 2, metrics.size
      assert_equal ["value", "value2"], metrics.map { |v| v[:key] }
      assert_equal 61.0, metrics[0]["_expire_at"]
      assert_equal 121.0, metrics[1]["_expire_at"]
    end

    stub_process_clock_time(62.0) do
      metrics << { key: "value3" }
      assert_equal 2, metrics.size
      assert_equal ["value2", "value3"], metrics.map { |v| v[:key] }
      assert_equal 121.0, metrics[0]["_expire_at"]
      assert_equal 122.0, metrics[1]["_expire_at"]
    end

    stub_process_clock_time(1000.0) do
      # check raw data before expiry event
      assert_equal 2, metrics.data.size

      num = 0
      metrics.each { |m| num += 1 }
      assert_equal 0, num
      assert_equal 0, metrics.size
    end
  end

  def test_container_with_filter
    metrics.filter = -> (new_metric, old_metric) do
      new_metric[:hostname] == old_metric[:hostname]
    end

    stub_process_clock_time(1.0) do
      metrics << { hostname: "host1", value: 100 }
      metrics << { hostname: "host2", value: 200 }
      metrics << { hostname: "host1", value: 200 }
      assert_equal 2, metrics.size
      assert_equal "host2", metrics[0][:hostname]
      assert_equal "host1", metrics[1][:hostname]
    end

    stub_process_clock_time(62.0) do
      metrics << { hostname: "host3", value: 300 }
      assert_equal 1, metrics.size
      assert_equal "host3", metrics[0][:hostname]
    end
  end
end
