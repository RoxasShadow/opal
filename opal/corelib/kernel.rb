module Kernel
  def method_missing(symbol, *args, &block)
    raise NoMethodError, "undefined method `#{symbol}' for #{inspect}"
  end

  def =~(obj)
    false
  end

  def ===(other)
    self == other
  end

  def <=>(other)
    %x{
      var x = #{self == other};

      if (x && x !== nil) {
        return 0;
      }

      return nil;
    }
  end

  def method(name)
    %x{
      var meth = self['$' + name];

      if (!meth || meth.$$stub) {
        #{raise NameError, "undefined method `#{name}' for class `#{self.class}'"};
      }

      return #{Method.new(self, `meth`, name)};
    }
  end

  def methods(all = true)
    %x{
      var methods = [];

      for (var key in self) {
        if (key[0] == "$" && typeof(self[key]) === "function") {
          if (all == false || all === nil) {
            if (!Opal.hasOwnProperty.call(self, key)) {
              continue;
            }
          }
          if (self[key].$$stub === undefined) {
            methods.push(key.substr(1));
          }
        }
      }

      return methods;
    }
  end

  def Array(object, *args, &block)
    %x{
      if (object == null || object === nil) {
        return [];
      }
      else if (#{object.respond_to? :to_ary}) {
        return #{object.to_ary};
      }
      else if (#{object.respond_to? :to_a}) {
        return #{object.to_a};
      }
      else {
        return [object];
      }
    }
  end

  def at_exit(&block)
    $__at_exit__ ||= []
    $__at_exit__ << block
  end

  # Opal does not support #caller, but we stub it as an empty array to not
  # break dependant libs
  def caller
    []
  end

  def class
    `self.$$class`
  end

  def copy_instance_variables(other)
    %x{
      for (var name in other) {
        if (name.charAt(0) !== '$') {
          self[name] = other[name];
        }
      }
    }
  end

  def clone
    copy = self.class.allocate

    copy.copy_instance_variables(self)
    copy.initialize_clone(self)

    copy
  end

  def initialize_clone(other)
    initialize_copy(other)
  end

  def define_singleton_method(name, &body)
    unless body
      raise ArgumentError, "tried to create Proc object without a block"
    end

    %x{
      var jsid   = '$' + name;
      body.$$jsid = name;
      body.$$s    = null;
      body.$$def  = body;

      #{singleton_class}.$$proto[jsid] = body;

      return self;
    }
  end

  def dup
    copy = self.class.allocate

    copy.copy_instance_variables(self)
    copy.initialize_dup(self)

    copy
  end

  def initialize_dup(other)
    initialize_copy(other)
  end

  def enum_for(method = :each, *args, &block)
    Enumerator.for(self, method, *args, &block)
  end

  alias to_enum enum_for

  def equal?(other)
    `self === other`
  end

  def exit(status = true)
    $__at_exit__.reverse.each(&:call) if $__at_exit__
    status = 0 if `status === true` # it's in JS because it can be null/undef
    `Opal.exit(status);`
    nil
  end

  def extend(*mods)
    %x{
      var singleton = #{singleton_class};

      for (var i = mods.length - 1; i >= 0; i--) {
        var mod = mods[i];

        #{`mod`.append_features `singleton`};
        #{`mod`.extended self};
      }
    }

    self
  end

  def format(format, *args)
    if args.length == 1 && args[0].respond_to?(:to_ary)
      args = args[0].to_ary
    end

    %x{
      var idx   = 0,
      idx_str   = '([1-9]\\d*\\$)?',
      flags     = '([-+ 0]*)',

      w_idx_str = '([1-9]\\d*\\$)?',
      width_str = '(\\d*|\\*' + w_idx_str + ')',

      p_idx_str = '([1-9]\\d*\\$)?',
      prec_str  = '(?:\\.(\\d*|\\*' + p_idx_str + '))?',

      spec      = '([cspdiubBoxXfgeEG])',

      valid     = '%' + idx_str + flags + width_str + prec_str + spec,
      hash_key  = '%\\{(\\w+)\\}',
      escaped   = '(%%)',
      invalid   = '(%[^\\n\\0])';

      return format.replace(new RegExp(valid + '|' + hash_key + '|' + escaped + '|' + invalid, 'g'), function(
        str,
        idx_str,
        flags,
        width_str,
        w_idx_str,
        prec_str,
        p_idx_str,
        spec,
        hash_key,
        escaped,
        invalid
      ) {
        if (hash_key) {
          if (args[0] !== undefined && args[0].$$is_hash) {
            return #{`args[0]`.fetch(`hash_key`)};
          }
          #{raise ArgumentError, 'one hash required'}
        }

        if (escaped) {
          return '%';
        }

        if (invalid) {
          if (invalid.charAt(1) === ' ') {
            #{raise ArgumentError, "invalid format character - %"}
          }
          else {
            #{raise ArgumentError, "malformed format string - #{`invalid`}"}
          }
        }

        var width,
            prec,
            is_integer_spec = ("diubBoxX".indexOf(spec) != -1),
            is_float_spec = ("eEfgG".indexOf(spec) != -1),
            prefix = '',
            obj;

        if (width_str === undefined) {
          width = undefined;
        }
        else if (width_str.charAt(0) == '*') {
          var w_idx = idx++;
          if (w_idx_str) {
            w_idx = parseInt(w_idx_str, 10) - 1;
          }
          width = #{`args[w_idx]`.to_i};
        }
        else {
          width = parseInt(width_str, 10);
        }

        if (!prec_str) {
          prec = is_float_spec ? 6 : undefined;
        }
        else if (prec_str.charAt(0) == '*') {
          var p_idx = idx++;
          if (p_idx_str) {
            p_idx = parseInt(p_idx_str, 10) - 1;
          }
          prec = #{`args[p_idx]`.to_i};
        }
        else {
          prec = parseInt(prec_str, 10);
        }

        if (idx_str) {
          idx = parseInt(idx_str, 10) - 1;
        }

        switch (spec) {
        case 'c':
          obj = args[idx];
          if (obj.$$is_string) {
            str = obj.charAt(0);
          }
          else if (#{`obj`.respond_to?(:to_str)}) {
            str = #{`obj`.to_str}.charAt(0);
          }
          else if (#{`obj`.respond_to?(:to_ary)}) {
            str = String.fromCharCode(#{`obj`.to_ary[0].to_int});
          }
          else {
            str = String.fromCharCode(#{`obj`.to_int});
          }
          break;

        case 's':
          str = #{`args[idx]`.to_s};
          if (prec !== undefined) {
            str = str.substr(0, prec);
          }
          break;

        case 'p':
          str = #{`args[idx]`.inspect};
          if (prec !== undefined) {
            str = str.substr(0, prec);
          }
          break;

        case 'd':
        case 'i':
        case 'u':
          str = #{`args[idx]`.to_i}.toString();
          break;

        case 'b':
        case 'B':
          str = #{`args[idx]`.to_i}.toString(2);
          break;

        case 'o':
          str = #{`args[idx]`.to_i}.toString(8);
          break;

        case 'x':
        case 'X':
          str = #{`args[idx]`.to_i}.toString(16);
          break;

        case 'e':
        case 'E':
          str = #{`args[idx]`.to_f}.toExponential(prec);
          break;

        case 'f':
          str = #{`args[idx]`.to_f}.toFixed(prec);
          break;

        case 'g':
        case 'G':
          str = #{`args[idx]`.to_f}.toPrecision(prec);
          break;
        }

        idx++;

        if (is_integer_spec || is_float_spec) {
          if (str.charAt(0) == '-') {
            prefix = '-';
            str = str.substr(1);
          }
          else {
            if (flags.indexOf('+') != -1) {
              prefix = '+';
            }
            else if (flags.indexOf(' ') != -1) {
              prefix = ' ';
            }
          }
        }

        if (is_integer_spec && prec !== undefined) {
          if (str.length < prec) {
            str = #{'0' * `prec - str.length`} + str;
          }
        }

        var total_len = prefix.length + str.length;

        if (width !== undefined && total_len < width) {
          if (flags.indexOf('-') != -1) {
            str = str + #{' ' * `width - total_len`};
          }
          else {
            var pad_char = ' ';
            if (flags.indexOf('0') != -1) {
              str = #{'0' * `width - total_len`} + str;
            }
            else {
              prefix = #{' ' * `width - total_len`} + prefix;
            }
          }
        }

        var result = prefix + str;

        if ('XEG'.indexOf(spec) != -1) {
          result = result.toUpperCase();
        }

        return result;
      });
    }
  end

  def freeze
    @___frozen___ = true
    self
  end

  def frozen?
    @___frozen___ || false
  end

  def hash
    "#{self.class}:#{self.class.__id__}:#{__id__}"
  end

  def initialize_copy(other)
  end

  def inspect
    to_s
  end

  def instance_of?(klass)
    `self.$$class === klass`
  end

  def instance_variable_defined?(name)
    `Opal.hasOwnProperty.call(self, name.substr(1))`
  end

  def instance_variable_get(name)
    %x{
      var ivar = self[name.substr(1)];

      return ivar == null ? nil : ivar;
    }
  end

  def instance_variable_set(name, value)
    `self[name.substr(1)] = value`
  end

  def instance_variables
    %x{
      var result = [];

      for (var name in self) {
        if (name.charAt(0) !== '$') {
          if (name !== '$$class' && name !== '$$id') {
            result.push('@' + name);
          }
        }
      }

      return result;
    }
  end

  def Integer(value, base = undefined)
    %x{
      var i, str, base_digits;

      if (!value.$$is_string) {
        if (base !== undefined) {
          #{raise ArgumentError, "base specified for non string value"}
        }
        if (value === nil) {
          #{raise TypeError, "can't convert nil into Integer"}
        }
        if (value.$$is_number) {
          if (value === Infinity || value === -Infinity || isNaN(value)) {
            #{raise FloatDomainError, value}
          }
          return Math.floor(value);
        }
        if (#{value.respond_to?(:to_int)}) {
          i = #{value.to_int};
          if (i !== nil) {
            return i;
          }
        }
        return #{Opal.coerce_to!(value, Integer, :to_i)};
      }

      if (base === undefined) {
        base = 0;
      } else {
        base = #{Opal.coerce_to(`base`, Integer, :to_int)};
        if (base === 1 || base < 0 || base > 36) {
          #{raise ArgumentError, "invalid radix #{base}"}
        }
      }

      str = value.toLowerCase();

      str = str.replace(/(\d)_(?=\d)/g, '$1');

      str = str.replace(/^(\s*[+-]?)(0[bodx]?)/, function (_, head, flag) {
        switch (flag) {
        case '0b':
          if (base === 0 || base === 2) {
            base = 2;
            return head;
          }
        case '0':
        case '0o':
          if (base === 0 || base === 8) {
            base = 8;
            return head;
          }
        case '0d':
          if (base === 0 || base === 10) {
            base = 10;
            return head;
          }
        case '0x':
          if (base === 0 || base === 16) {
            base = 16;
            return head;
          }
        }
        #{raise ArgumentError, "invalid value for Integer(): \"#{value}\""}
      });

      base = (base === 0 ? 10 : base);

      base_digits = '0-' + (base <= 10 ? base - 1 : '9a-' + String.fromCharCode(97 + (base - 11)));

      if (!(new RegExp('^\\s*[+-]?[' + base_digits + ']+\\s*$')).test(str)) {
        #{raise ArgumentError, "invalid value for Integer(): \"#{value}\""}
      }

      i = parseInt(str, base);

      if (isNaN(i)) {
        #{raise ArgumentError, "invalid value for Integer(): \"#{value}\""}
      }

      return i;
    }
  end

  def Float(value)
    %x{
      var str;

      if (value === nil) {
        #{raise TypeError, "can't convert nil into Float"}
      }

      if (value.$$is_string) {
        str = value.toString();

        str = str.replace(/(\d)_(?=\d)/g, '$1');

        //Special case for hex strings only:
        if (/^\s*[-+]?0[xX][0-9a-fA-F]+\s*$/.test(str)) {
          return #{Integer(`str`)};
        }

        if (!/^\s*[-+]?[0-9]*\.?[0-9]+([eE][-+]?[0-9]+)?\s*$/.test(str)) {
          #{raise ArgumentError, "invalid value for Float(): \"#{value}\""}
        }

        return parseFloat(str);
      }

      return #{Opal.coerce_to!(value, Float, :to_f)};
    }
  end

  def is_a?(klass)
    `Opal.is_a(self, klass)`
  end

  alias kind_of? is_a?

  def lambda(&block)
    `block.$$is_lambda = true`

    block
  end

  def load(file)
    file = Opal.coerce_to!(file, String, :to_str)
    `Opal.load(Opal.normalize_loadable_path(#{file}))`
  end

  def loop(&block)
    %x{
      while (true) {
        if (block() === $breaker) {
          return $breaker.$v;
        }
      }
    }

    self
  end

  def nil?
    false
  end

  alias object_id __id__

  def printf(*args)
    if args.length > 0
      print format(*args)
    end

    nil
  end

  def private_methods(*)
    []
  end
  alias private_instance_methods private_methods

  def proc(&block)
    unless block
      raise ArgumentError, "tried to create Proc object without a block"
    end

    `block.$$is_lambda = false`
    block
  end

  def puts(*strs)
    $stdout.puts(*strs)
  end

  def p(*args)
    args.each { |obj| $stdout.puts obj.inspect }

    args.length <= 1 ? args[0] : args
  end

  def print(*strs)
    $stdout.print(*strs)
  end

  def warn(*strs)
    $stderr.puts(*strs) unless $VERBOSE.nil? || strs.empty?
  end

  def raise(exception = undefined, string = undefined)
    %x{
      if (exception == null && #$!) {
        throw #$!;
      }

      if (exception == null) {
        exception = #{RuntimeError.new};
      }
      else if (exception.$$is_string) {
        exception = #{RuntimeError.new exception};
      }
      else if (exception.$$is_class) {
        exception = #{exception.new string};
      }

      #$! = exception;

      throw exception;
    }
  end

  alias fail raise

  def rand(max = undefined)
    %x{
      if (max === undefined) {
        return Math.random();
      }
      else if (max.$$is_range) {
        var arr = #{max.to_a};

        return arr[#{rand(`arr.length`)}];
      }
      else {
        return Math.floor(Math.random() *
          Math.abs(#{Opal.coerce_to max, Integer, :to_int}));
      }
    }
  end

  def respond_to?(name, include_all = false)
    return true if respond_to_missing?(name)

    %x{
      var body = self['$' + name];

      if (typeof(body) === "function" && !body.$$stub) {
        return true;
      }
    }

    false
  end

  def respond_to_missing?(method_name)
    false
  end

  def require(file)
    file = Opal.coerce_to!(file, String, :to_str)
    `Opal.require(Opal.normalize_loadable_path(#{file}))`
  end

  def require_relative(file)
    Opal.try_convert!(file, String, :to_str)
    file = File.expand_path File.join(`Opal.current_file`, '..', file)

    `Opal.require(Opal.normalize_loadable_path(#{file}))`
  end

  # `path` should be the full path to be found in registered modules (`Opal.modules`)
  def require_tree(path)
    path = File.expand_path(path)

    %x{
      for (var name in Opal.modules) {
        if (#{`name`.start_with?(path)}) {
          Opal.require(name);
        }
      }
    }

    nil
  end

  alias send        __send__
  alias public_send __send__

  def singleton_class
    `Opal.get_singleton_class(self)`
  end

  alias sprintf format

  alias srand rand

  def String(str)
    `String(str)`
  end

  def taint
    self
  end

  def tainted?
    false
  end

  def tap(&block)
    yield self
    self
  end

  def to_proc
    self
  end

  def to_s
    "#<#{self.class}:0x#{__id__.to_s(16)}>"
  end

  alias untaint taint
end
