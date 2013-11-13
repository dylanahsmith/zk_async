class ZkAsync::Client
  def initialize(zk)
    @zk = zk
  end

  def create(*args, &block); send_request(__method__, *args); end
  def get(*args, &block); send_request(__method__, *args); end
  def set(*args, &block); send_request(__method__, *args); end
  def stat(*args, &block); send_request(__method__, *args); end
  def children(*args, &block); send_request(__method__, *args); end
  def delete(*args, &block); send_request(__method__, *args); end
  def get_acl(*args, &block); send_request(__method__, *args); end
  def set_acl(*args, &block); send_request(__method__, *args); end

  def create_path(path, options={})
    create(path, options).rescue(ZK::Exceptions::NoNode) do |exc|
      raise exc if path == "/"
      mkdir_p(File.dirname(path))
        .chain { create(path, options) }
    end
  end

  def mkdir_p(path)
    create(path)
      .rescue(ZK::Exceptions::NodeExists)
      .rescue(ZK::Exceptions::NoNode) do
        raise exc if path == "/"
        mkdir_p(File.dirname(path)).chain{ mkdir_p(path) }
      end
  end

  def rm_rf(path)
    self.children(path)
      .chain { |children| children.map{ |child| rm_rf("#{path}/#{child}") } }
      .chain { delete(path) }
  end

  def result(value)
    ZkAsync::Result.new.set(value)
  end

  def result_group(results)
    ZkAsync::Result.new.group(results)
  end

  def shared_locker(*args)
    ZkAsync::Locker::Shared.new(self, *args)
  end

  def exclusive_locker(*args)
    ZkAsync::Locker::Exclusive.new(self, *args)
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
      if error_code == 0
        result.set(value)
      else
        result.set_exception(ZK::Exceptions::KeeperException.by_code(error_code))
      end
    rescue Exception => exc
      result.set_exception(exc) unless result.set?
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
