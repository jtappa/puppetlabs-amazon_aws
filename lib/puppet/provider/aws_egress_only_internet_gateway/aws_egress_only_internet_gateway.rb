require "pry"
# require "pry-rescue"
require "json"
require "facets"
require "retries"


require "aws-sdk-ec2"


Puppet::Type.type(:aws_egress_only_internet_gateway).provide(:arm) do
  mk_resource_methods

  def initialize(value = {})
    super(value)
    @property_flush = {}
    @is_create = false
    @is_delete = false
  end
    
  def namevar
    :egress_only_internet_gateway_id
  end

  # Properties

  def attachments=(value)
    Puppet.info("attachments setter called to change to #{value}")
    @property_flush[:attachments] = value
  end

  def client_token=(value)
    Puppet.info("client_token setter called to change to #{value}")
    @property_flush[:client_token] = value
  end

  def dry_run=(value)
    Puppet.info("dry_run setter called to change to #{value}")
    @property_flush[:dry_run] = value
  end

  def egress_only_internet_gateway_id=(value)
    Puppet.info("egress_only_internet_gateway_id setter called to change to #{value}")
    @property_flush[:egress_only_internet_gateway_id] = value
  end

  def egress_only_internet_gateway_ids=(value)
    Puppet.info("egress_only_internet_gateway_ids setter called to change to #{value}")
    @property_flush[:egress_only_internet_gateway_ids] = value
  end

  def max_results=(value)
    Puppet.info("max_results setter called to change to #{value}")
    @property_flush[:max_results] = value
  end

  def next_token=(value)
    Puppet.info("next_token setter called to change to #{value}")
    @property_flush[:next_token] = value
  end

  def vpc_id=(value)
    Puppet.info("vpc_id setter called to change to #{value}")
    @property_flush[:vpc_id] = value
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
    client.describe_egress_only_internet_gateways.each do |response|
      response.egress_only_internet_gateways.each do |i|
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
    attachments = instance.respond_to?(:attachments) ? (instance.attachments.respond_to?(:to_hash) ? instance.attachments.to_hash : instance.attachments ) : nil
    client_token = instance.respond_to?(:client_token) ? (instance.client_token.respond_to?(:to_hash) ? instance.client_token.to_hash : instance.client_token ) : nil
    dry_run = instance.respond_to?(:dry_run) ? (instance.dry_run.respond_to?(:to_hash) ? instance.dry_run.to_hash : instance.dry_run ) : nil
    egress_only_internet_gateway_id = instance.respond_to?(:egress_only_internet_gateway_id) ? (instance.egress_only_internet_gateway_id.respond_to?(:to_hash) ? instance.egress_only_internet_gateway_id.to_hash : instance.egress_only_internet_gateway_id ) : nil
    egress_only_internet_gateway_ids = instance.respond_to?(:egress_only_internet_gateway_ids) ? (instance.egress_only_internet_gateway_ids.respond_to?(:to_hash) ? instance.egress_only_internet_gateway_ids.to_hash : instance.egress_only_internet_gateway_ids ) : nil
    max_results = instance.respond_to?(:max_results) ? (instance.max_results.respond_to?(:to_hash) ? instance.max_results.to_hash : instance.max_results ) : nil
    next_token = instance.respond_to?(:next_token) ? (instance.next_token.respond_to?(:to_hash) ? instance.next_token.to_hash : instance.next_token ) : nil
    vpc_id = instance.respond_to?(:vpc_id) ? (instance.vpc_id.respond_to?(:to_hash) ? instance.vpc_id.to_hash : instance.vpc_id ) : nil

    hash = {}
    hash[:ensure] = :present
    hash[:object] = instance
    hash[:name] = name_from_tag(instance)
    hash[:tags] = instance.tags if instance.respond_to?(:tags) and instance.tags.size > 0
    hash[:tag_set] = instance.tag_set if instance.respond_to?(:tag_set) and instance.tag_set.size > 0

    hash[:attachments] = attachments unless attachments.nil?
    hash[:client_token] = client_token unless client_token.nil?
    hash[:dry_run] = dry_run unless dry_run.nil?
    hash[:egress_only_internet_gateway_id] = egress_only_internet_gateway_id unless egress_only_internet_gateway_id.nil?
    hash[:egress_only_internet_gateway_ids] = egress_only_internet_gateway_ids unless egress_only_internet_gateway_ids.nil?
    hash[:max_results] = max_results unless max_results.nil?
    hash[:next_token] = next_token unless next_token.nil?
    hash[:vpc_id] = vpc_id unless vpc_id.nil?
    hash
  end

  def create
    @is_create = true
    Puppet.info("Entered create for resource #{resource[:name]} of type Instances")
    client = Aws::EC2::Client.new(region: self.class.get_region)
    response = client.create_egress_only_internet_gateway(build_hash)
    res = response.respond_to?(:egress_only_internet_gateway) ? response.egress_only_internet_gateway : response
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
    egress_only_internet_gateway = {}
    if @is_create || @is_update
      egress_only_internet_gateway[:client_token] = resource[:client_token] unless resource[:client_token].nil?
      egress_only_internet_gateway[:dry_run] = resource[:dry_run] unless resource[:dry_run].nil?
      egress_only_internet_gateway[:egress_only_internet_gateway_id] = resource[:egress_only_internet_gateway_id] unless resource[:egress_only_internet_gateway_id].nil?
      egress_only_internet_gateway[:egress_only_internet_gateway_ids] = resource[:egress_only_internet_gateway_ids] unless resource[:egress_only_internet_gateway_ids].nil?
      egress_only_internet_gateway[:max_results] = resource[:max_results] unless resource[:max_results].nil?
      egress_only_internet_gateway[:next_token] = resource[:next_token] unless resource[:next_token].nil?
      egress_only_internet_gateway[:vpc_id] = resource[:vpc_id] unless resource[:vpc_id].nil?
    end
    return symbolize(egress_only_internet_gateway)
  end

  def destroy
    Puppet.info("Entered delete for resource #{resource[:name]}")
    @is_delete = true
    Puppet.info("Calling operation delete_egress_only_internet_gateway")
    client = Aws::EC2::Client.new(region: self.class.get_region)
    client.delete_egress_only_internet_gateway({namevar => resource.provider.property_hash[namevar]})
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
