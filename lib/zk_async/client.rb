class ZkAsync::Client
  def initialize(zk)
    @zk = zk
  end

  def create(*args, &block); send_request(__method__, *args, &block); end
  def get(*args, &block); send_request(__method__, *args, &block); end
  def set(*args, &block); send_request(__method__, *args, &block); end
  def stat(*args, &block); send_request(__method__, *args, &block); end
  def children(*args, &block); send_request(__method__, *args, &block); end
  def delete(*args, &block); send_request(__method__, *args, &block); end
  def get_acl(*args, &block); send_request(__method__, *args, &block); end
  def set_acl(*args, &block); send_request(__method__, *args, &block); end

  def create_path(path, options={}, &block)
    result = self.result(&block)
    create(path, options) do |node_path, error|
      if error == ZK::Exceptions::NoNode && path != "/"
        mkdir_p(File.dirname(path)) do |_, error|
          if error
            result.set_error(error)
          else
            create(path, options, &result.method(:set))
          end
        end
      else
        result.set(node_path, error)
      end
    end
    result
  end

  def mkdir_p(path, &block)
    result = self.result(&block)
    create(path) do |_, error|
      if error == ZK::Exceptions::NodeExists
        result.set(true)
      elsif error == ZK::Exceptions::NoNode && path != "/"
        mkdir_p(File.dirname(path)) do |value, error|
          if error
            result.set_error(error)
          else
            mkdir_p(path, &result.method(:set))
          end
        end
      else
        result.set(!error, error)
      end
    end
    result
  end

  def rm_rf(path, &block)
    result = self.result(&block)
    self.children(path) do |children, error|
      if error
        result.set(0, error)
      else
        subresults = children.map{ |child| rm_rf("#{path}/#{child}") }
        self.result.group(subresults) do |_, error|
          delete_count = subresults.reduce(0){ |t, r| t + r.get.first }
          if error
            result.set(delete_count, error)
          else
            delete(path) do |subresult, error|
              delete_count += 1 unless error
              result.set(delete_count, error)
            end
          end
        end
      end
    end
    result
  end

  def result(&block)
    ZkAsync::Result.new(&block)
  end

  private

  class RequestCallback < Struct.new(:result, :method_name)
    def initialize(method_name, &block)
      self.result = ZkAsync::Result.new(&block)
      @method_name = method_name
    end

    def call(res_hash)
      value = translate_response(res_hash)
      error_code = res_hash[:rc]
      error = error_code == 0 ? nil : ZK::Exceptions::KeeperException.by_code(error_code)
      result.set(value, error)
    rescue Exception => exc
      result.set_error(exc) unless result.finished
      raise
    end

    def translate_response(res_hash)
      case @method_name
      when :create
        res_hash[:string]
      when :get
        res_hash.values_at(:data, :stat)
      when :set
        res_hash[:stat]
      when :stat
        res_hash[:stat]
      when :children
        res_hash[:strings]
      when :delete
        nil
      when :get_acl
        res_hash.values_at(:acl, :stat)
      when :set_acl
        res_hash[:stat]
      end
    end
  end

  def send_request(method_name, *args, &block)
    callback = RequestCallback.new(method_name, &block)
    options = args.extract_options!
    options[:callback] = callback.method(:call)
    args.push(options)
    @zk.send(method_name, *args)
    callback.result
  end
end
