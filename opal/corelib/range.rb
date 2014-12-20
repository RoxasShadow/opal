require 'corelib/enumerable'

class Range
  include Enumerable

  `def.$$is_range = true;`

  attr_reader :begin, :end

  def initialize(first, last, exclude = false)
    raise ArgumentError unless first <=> last

    @begin   = first
    @end     = last
    @exclude = exclude
  end

  def ==(other)
    %x{
      if (!other.$$is_range) {
        return false;
      }

      return self.exclude === other.exclude &&
             self.begin   ==  other.begin &&
             self.end     ==  other.end;
    }
  end

  def ===(value)
    include? value
  end

  def cover?(value)
    @begin <= value && (@exclude ? value < @end : value <= @end)
  end

  def each(&block)
    return enum_for :each unless block_given?

    current = @begin
    last    = @end

    while current < last
      yield current

      current = current.succ
    end

    yield current if !@exclude && current == last

    self
  end

  def eql?(other)
    return false unless Range === other

    @exclude === other.exclude_end? &&
    @begin.eql?(other.begin) &&
    @end.eql?(other.end)
  end

  def exclude_end?
    @exclude
  end

  alias :first :begin

  alias :include? :cover?

  alias :last :end

  # FIXME: currently hardcoded to assume range holds numerics
  def max
    if block_given?
      super
    else
      `#@exclude ? #@end - 1 : #@end`
    end
  end

  alias :member? :cover?

  def min
    if block_given?
      super
    else
      @begin
    end
  end

  alias member? include?

  def size
    _begin = @begin
    _end   = @end
    _end  -= 1 if @exclude

    return nil unless Numeric === _begin && Numeric === _end
    return 0 if _end < _begin
    infinity = Float::INFINITY
    return infinity if infinity == _begin.abs || _end.abs == infinity

    (`Math.abs(_end - _begin) + 1`).to_i
  end

  def step(step_size = 1, &block)
    return enum_for :step, step_size unless block_given?

    raise NotImplementedError if step_size.is_a?(Float)

    step_size = Integer(from = step_size) rescue nil
    raise TypeError, "no implicit conversion of #{from.class} into Integer" unless step_size.is_a?(Integer)

    raise ArgumentError, "step can't be negative" if step_size < 0
    raise ArgumentError, "step can't be 0" if step_size == 0

    i = 0
    each do |curr|
      yield curr if i % step_size == 0
      i += 1
    end

    self
  end

  def to_s
    `#{@begin.inspect} + (#@exclude ? '...' : '..') + #{@end.inspect}`
  end

  alias inspect to_s
end
