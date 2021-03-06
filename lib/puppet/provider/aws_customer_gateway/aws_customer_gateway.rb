require "pry"
# require "pry-rescue"
require "json"
require "facets"
require "retries"


require "aws-sdk-ec2"


Puppet::Type.type(:aws_customer_gateway).provide(:arm) do
  mk_resource_methods

  def initialize(value = {})
    super(value)
    @property_flush = {}
    @is_create = false
    @is_delete = false
  end
    
  def namevar
    :customer_gateway_id
  end

  # Properties

  def bgp_asn=(value)
    Puppet.info("bgp_asn setter called to change to #{value}")
    @property_flush[:bgp_asn] = value
  end

  def customer_gateway_id=(value)
    Puppet.info("customer_gateway_id setter called to change to #{value}")
    @property_flush[:customer_gateway_id] = value
  end

  def customer_gateway_ids=(value)
    Puppet.info("customer_gateway_ids setter called to change to #{value}")
    @property_flush[:customer_gateway_ids] = value
  end

  def dry_run=(value)
    Puppet.info("dry_run setter called to change to #{value}")
    @property_flush[:dry_run] = value
  end

  def filters=(value)
    Puppet.info("filters setter called to change to #{value}")
    @property_flush[:filters] = value
  end

  def ip_address=(value)
    Puppet.info("ip_address setter called to change to #{value}")
    @property_flush[:ip_address] = value
  end

  def public_ip=(value)
    Puppet.info("public_ip setter called to change to #{value}")
    @property_flush[:public_ip] = value
  end

  def state=(value)
    Puppet.info("state setter called to change to #{value}")
    @property_flush[:state] = value
  end

  def tags=(value)
    Puppet.info("tags setter called to change to #{value}")
    @property_flush[:tags] = value
  end

  def type=(value)
    Puppet.info("type setter called to change to #{value}")
    @property_flush[:type] = value
  end


  def name=(value)
    Puppet.info("name setter called to change to #{value}")
    @property_flush[:name] = value
  end

  def self.get_region
    ENV['AWS_REGION'] || 'us-west-2'
  end

  def self.has_name?(hash)
    !hash[:name].nil? && !hash[:name].empty?
  end
  def self.instances
    Puppet.debug("Calling instances for region #{self.get_region}")
    client = Aws::EC2::Client.new(region: self.get_region)

    all_instances = []
    client.describe_customer_gateways.each do |response|
      response.customer_gateways.each do |i|
        hash = instance_to_hash(i)
        all_instances << new(hash) if has_name?(hash)
      end
    end
    all_instances
  end

  def self.prefetch(resources)
    instances.each do |prov|
      tags = prov.respond_to?(:tags) ? prov.tags : nil
      tags = prov.respond_to?(:tag_set) ? prov.tag_set : tags
      if tags 
        name = tags.find { |x| x[:key] == "Name" }[:value]
        if (resource = (resources.find { |k, v| k.casecmp(name).zero? } || [])[1])
          resource.provider = prov
        end
      end
    end
  end

  def self.name_from_tag(instance)
    tags = instance.respond_to?(:tags) ? instance.tags : nil
    tags = instance.respond_to?(:tag_set) ? instance.tag_set : tags
    name = tags.find { |x| x.key == 'Name' } unless tags.nil?
    name.value unless name.nil?
  end

  def self.instance_to_hash(instance)
    bgp_asn = instance.respond_to?(:bgp_asn) ? (instance.bgp_asn.respond_to?(:to_hash) ? instance.bgp_asn.to_hash : instance.bgp_asn ) : nil
    customer_gateway_id = instance.respond_to?(:customer_gateway_id) ? (instance.customer_gateway_id.respond_to?(:to_hash) ? instance.customer_gateway_id.to_hash : instance.customer_gateway_id ) : nil
    customer_gateway_ids = instance.respond_to?(:customer_gateway_ids) ? (instance.customer_gateway_ids.respond_to?(:to_hash) ? instance.customer_gateway_ids.to_hash : instance.customer_gateway_ids ) : nil
    dry_run = instance.respond_to?(:dry_run) ? (instance.dry_run.respond_to?(:to_hash) ? instance.dry_run.to_hash : instance.dry_run ) : nil
    filters = instance.respond_to?(:filters) ? (instance.filters.respond_to?(:to_hash) ? instance.filters.to_hash : instance.filters ) : nil
    ip_address = instance.respond_to?(:ip_address) ? (instance.ip_address.respond_to?(:to_hash) ? instance.ip_address.to_hash : instance.ip_address ) : nil
    public_ip = instance.respond_to?(:public_ip) ? (instance.public_ip.respond_to?(:to_hash) ? instance.public_ip.to_hash : instance.public_ip ) : nil
    state = instance.respond_to?(:state) ? (instance.state.respond_to?(:to_hash) ? instance.state.to_hash : instance.state ) : nil
    tags = instance.respond_to?(:tags) ? (instance.tags.respond_to?(:to_hash) ? instance.tags.to_hash : instance.tags ) : nil
    type = instance.respond_to?(:type) ? (instance.type.respond_to?(:to_hash) ? instance.type.to_hash : instance.type ) : nil

    hash = {}
    hash[:ensure] = :present
    hash[:object] = instance
    hash[:name] = name_from_tag(instance)
    hash[:tags] = instance.tags if instance.respond_to?(:tags) and instance.tags.size > 0
    hash[:tag_set] = instance.tag_set if instance.respond_to?(:tag_set) and instance.tag_set.size > 0

    hash[:bgp_asn] = bgp_asn unless bgp_asn.nil?
    hash[:customer_gateway_id] = customer_gateway_id unless customer_gateway_id.nil?
    hash[:customer_gateway_ids] = customer_gateway_ids unless customer_gateway_ids.nil?
    hash[:dry_run] = dry_run unless dry_run.nil?
    hash[:filters] = filters unless filters.nil?
    hash[:ip_address] = ip_address unless ip_address.nil?
    hash[:public_ip] = public_ip unless public_ip.nil?
    hash[:state] = state unless state.nil?
    hash[:tags] = tags unless tags.nil?
    hash[:type] = type unless type.nil?
    hash
  end

  def create
    @is_create = true
    Puppet.info("Entered create for resource #{resource[:name]} of type Instances")
    client = Aws::EC2::Client.new(region: self.class.get_region)
    response = client.create_customer_gateway(build_hash)
    res = response.respond_to?(:customer_gateway) ? response.customer_gateway : response
    with_retries(:max_tries => 5) do  
      client.create_tags(
        resources: [res.to_hash[namevar]],
        tags: [{ key: 'Name', value: resource.provider.name}]
      )
    end
    @property_hash[:ensure] = :present
  rescue Exception => ex
    Puppet.alert("Exception during create. The state of the resource is unknown.  ex is #{ex} and backtrace is #{ex.backtrace}")
    raise
  end

  def flush
    Puppet.info("Entered flush for resource #{name} of type <no value> - creating ? #{@is_create}, deleting ? #{@is_delete}")
    if @is_create || @is_delete
      return # we've already done the create or delete
    end
    @is_update = true
    hash = build_hash
    Puppet.info("Calling Update on flush")
    @property_hash[:ensure] = :present
    response = []
  end

  def build_hash
    customer_gateway = {}
    if @is_create || @is_update
      customer_gateway[:bgp_asn] = resource[:bgp_asn] unless resource[:bgp_asn].nil?
      customer_gateway[:customer_gateway_id] = resource[:customer_gateway_id] unless resource[:customer_gateway_id].nil?
      customer_gateway[:customer_gateway_ids] = resource[:customer_gateway_ids] unless resource[:customer_gateway_ids].nil?
      customer_gateway[:dry_run] = resource[:dry_run] unless resource[:dry_run].nil?
      customer_gateway[:filters] = resource[:filters] unless resource[:filters].nil?
      customer_gateway[:public_ip] = resource[:public_ip] unless resource[:public_ip].nil?
      customer_gateway[:type] = resource[:type] unless resource[:type].nil?
    end
    return symbolize(customer_gateway)
  end

  def destroy
    Puppet.info("Entered delete for resource #{resource[:name]}")
    @is_delete = true
    Puppet.info("Calling operation delete_customer_gateway")
    client = Aws::EC2::Client.new(region: self.class.get_region)
    client.delete_customer_gateway({namevar => resource.provider.property_hash[namevar]})
    @property_hash[:ensure] = :absent
  end


  # Shared funcs
  def exists?
    return_value = @property_hash[:ensure] && @property_hash[:ensure] != :absent
    Puppet.info("Checking if resource #{name} of type <no value> exists, returning #{return_value}")
    return_value
  end

  def property_hash
    @property_hash
  end


  def symbolize(obj)
    return obj.reduce({}) do |memo, (k, v)|
      memo.tap { |m| m[k.to_sym] = symbolize(v) }
    end if obj.is_a? Hash

    return obj.reduce([]) do |memo, v|
      memo << symbolize(v); memo
    end if obj.is_a? Array
    obj
  end
end

# this is the end of the ruby class
