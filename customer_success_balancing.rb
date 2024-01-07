require 'minitest/autorun'
require 'timeout'

class CustomerSuccessBalancing
  def initialize(customer_success, customers, away_customer_success)
    @customer_success = customer_success
    @customers = customers
    @away_customer_success = away_customer_success
  end

  # Returns the ID of the customer success with most customers
  def execute
    working_customer_success = find_working_customer_success(@customer_success, @away_customer_success)
    working_customer_success_hash = create_working_customer_success_hash(working_customer_success)

    @customers.each do |customer|
      available_customer_success = find_available_customer_success(working_customer_success_hash, customer)
      assign_customer_to_customer_success(working_customer_success_hash, available_customer_success, customer)
    end

    find_customer_success_with_max_customers(working_customer_success_hash)
  end

  def find_customer_success_with_max_customers(working_customer_success_hash)
    max_customers = working_customer_success_hash.group_by { |_, customer_success| customer_success[:customers].length }
                                                 .max_by { |customers_size| customers_size }

    max_customers[1].length > 1 ? 0 : max_customers[1].first[0]
  end

  def assign_customer_to_customer_success(working_customer_success_hash, available_customer_success, customer)
    return unless available_customer_success

    get_customers_from_customer_success(working_customer_success_hash, available_customer_success) << customer[:id]
  end

  def get_customers_from_customer_success(working_customer_success_hash, customer_success)
    working_customer_success_hash[customer_success[0]][:customers]
  end

  def find_available_customer_success(working_customer_success_hash, customer)
    working_customer_success_hash
      .select { |_, customer_success| customer_success[:score] >= customer[:score] }
      .min_by { |_, customer_success| customer_success[:customers].length && customer_success[:score] }
  end

  def create_working_customer_success_hash(working_customer_success)
    working_customer_success.each_with_object({}) do |customer_success, hash|
      hash[customer_success[:id]] = { score: customer_success[:score], customers: [] }
    end
  end

  def find_working_customer_success(customer_success, away_customer_success)
    customer_success.reject { |cs| away_customer_success.include?(cs[:id]) }
  end
end

class CustomerSuccessBalancingTests < Minitest::Test
  # ---- Integration tests scenarios ----
  def test_scenario_one
    balancer = CustomerSuccessBalancing.new(
      build_scores([60, 20, 95, 75]),
      build_scores([90, 20, 70, 40, 60, 10]),
      [2, 4]
    )
    assert_equal 1, balancer.execute
  end

  def test_scenario_two
    balancer = CustomerSuccessBalancing.new(
      build_scores([11, 21, 31, 3, 4, 5]),
      build_scores([10, 10, 10, 20, 20, 30, 30, 30, 20, 60]),
      []
    )
    assert_equal 0, balancer.execute
  end

  def test_scenario_three
    balancer = CustomerSuccessBalancing.new(
      build_scores(Array(1..999)),
      build_scores(Array.new(10_000, 998)),
      [999]
    )
    result = Timeout.timeout(1.0) { balancer.execute }
    assert_equal 998, result
  end

  def test_scenario_four
    balancer = CustomerSuccessBalancing.new(
      build_scores([1, 2, 3, 4, 5, 6]),
      build_scores([10, 10, 10, 20, 20, 30, 30, 30, 20, 60]),
      []
    )
    assert_equal 0, balancer.execute
  end

  def test_scenario_five
    balancer = CustomerSuccessBalancing.new(
      build_scores([100, 2, 3, 6, 4, 5]),
      build_scores([10, 10, 10, 20, 20, 30, 30, 30, 20, 60]),
      []
    )
    assert_equal 1, balancer.execute
  end

  def test_scenario_six
    balancer = CustomerSuccessBalancing.new(
      build_scores([100, 99, 88, 3, 4, 5]),
      build_scores([10, 10, 10, 20, 20, 30, 30, 30, 20, 60]),
      [1, 3, 2]
    )
    assert_equal 0, balancer.execute
  end

  def test_scenario_seven
    balancer = CustomerSuccessBalancing.new(
      build_scores([100, 99, 88, 3, 4, 5]),
      build_scores([10, 10, 10, 20, 20, 30, 30, 30, 20, 60]),
      [4, 5, 6]
    )
    assert_equal 3, balancer.execute
  end

  def test_scenario_eight
    balancer = CustomerSuccessBalancing.new(
      build_scores([60, 40, 95, 75]),
      build_scores([90, 70, 20, 40, 60, 10]),
      [2, 4]
    )
    assert_equal 1, balancer.execute
  end

  # ---- Unit tests ----

  def test_assign_customer_to_customer_success
    balancer = CustomerSuccessBalancing.new([], [], [])
    customer_success_hash = { 1 => { score: 60, customers: [] } }
    customer = { id: 1, score: 60 }

    balancer.assign_customer_to_customer_success(customer_success_hash, [1, { score: 60, customers: [] }], customer)

    assert_equal [1], customer_success_hash[1][:customers]
  end

  def test_get_customers_from_customer_success
    balancer = CustomerSuccessBalancing.new([], [], [])
    customer_success_hash = { 1 => { score: 60, customers: [1, 2, 3] } }

    result = balancer.get_customers_from_customer_success(customer_success_hash, [1, { score: 60, customers: [] }])

    assert_equal [1, 2, 3], result
  end

  def test_find_available_customer_success
    balancer = CustomerSuccessBalancing.new([], [], [])
    customer_success_hash = { 1 => { score: 60, customers: [] }, 2 => { score: 70, customers: [] } }
    customer = { id: 1, score: 65 }

    result = balancer.find_available_customer_success(customer_success_hash, customer)

    assert_equal [2, { score: 70, customers: [] }], result
  end

  def test_find_customer_success_with_max_customers
    balancer = CustomerSuccessBalancing.new([], [], [])
    customer_success_hash = { 1 => { score: 60, customers: [1, 2, 3] }, 2 => { score: 70, customers: [4, 5] } }

    result = balancer.find_customer_success_with_max_customers(customer_success_hash)

    assert_equal 1, result
  end

  def test_find_customer_success_with_max_customers_equals
    balancer = CustomerSuccessBalancing.new([], [], [])
    customer_success_hash = { 1 => { score: 60, customers: [1, 2, 3] }, 2 => { score: 70, customers: [4, 5, 6] } }

    result = balancer.find_customer_success_with_max_customers(customer_success_hash)

    assert_equal 0, result
  end

  def test_create_working_customer_success_hash
    balancer = CustomerSuccessBalancing.new([], [], [])
    working_customer_success = [
      { id: 1, score: 60 },
      { id: 2, score: 70 },
      { id: 3, score: 80 }
    ]

    result = balancer.create_working_customer_success_hash(working_customer_success)

    assert_equal({ 1 => { score: 60, customers: [] },
                   2 => { score: 70, customers: [] },
                   3 => { score: 80, customers: [] } }, result)
  end

  def test_find_working_customer_success
    balancer = CustomerSuccessBalancing.new([], [], [2, 3])
    customer_success = [
      { id: 1, score: 60 },
      { id: 2, score: 70 },
      { id: 3, score: 80 }
    ]

    away_customer_success = [2, 3]

    result = balancer.find_working_customer_success(customer_success, away_customer_success)

    assert_equal([{ id: 1, score: 60 }], result)
  end

  private

  def build_scores(scores)
    scores.map.with_index do |score, index|
      { id: index + 1, score: score }
    end
  end
end
