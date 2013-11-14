require 'rubygems'

begin
  require 'nokogiri'
  require 'json'
rescue Exception => e
  puts "Please ensure json and nokogiri gems are installed"

  raise e
end

require 'open-uri'
require 'cgi'
require 'csv'

class Grabber

  ################
  # Constants
  ################
  HOSTS = ["thiecom", "difona", "funktechnik-bielefeld"]


  #######################
  # Attributre Accessors
  #######################
  attr_accessor :url, :product, :document, :grabber_site, :csv, :host_with_price

  ################################
  # Class Object When Initialized
  ################################

  # Options will here take the hash which would contain different options
  def initialize(options = {})
    self.product          = options[:product]
    self.csv              = options[:csv]
    self.host_with_price  = {}
  end

  ##########################
  # Public Methods
  ##########################
  def parse
    HOSTS.each do |host|
      self.grabber_site = host.gsub("-", "_").to_sym

      self.url = fetch_product_url

      puts "Product Url - #{url}"

      if url
        self.document     = fetch_url
        parse_for grabber_site
      end
    end

    csv << [product, host_with_price[:thiecom], host_with_price[:difona], host_with_price[:funktechnik_bielefeld]]

  end

  ##########################
  # Private Methods
  ##########################
  private

  def fetch_url
    return Nokogiri::HTML(open(url,
              "User-Agent" => "Mozilla/5.0 (Windows NT 6.2; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/32.0.1667.0 Safari/537.36"
            )
          )
  end

  def parse_for(grabber_for = nil)
    return nil if grabber_for.nil?

    key       = get_key.to_sym
    node_hash = grabber_for_options[key]

    fetch_product(node_hash)
  end

  def fetch_product(node_hash)
    if grabber_site == :difona
      fetch_product_for_difona
    else
      document.css(node_hash[:parent_node]).each do |node|
        # Search for prodcut title
        node.css(node_hash[:title_node]).each_with_index do |title_node, index|

          if product_matched?(title_node.content, product)
            matched_title = title_node.content
            #searh for price in the node
            price = node.css(node_hash[:price_node])[index].content
            self.host_with_price[grabber_site] = price
          end
        end
      end
    end
  end

  def fetch_product_for_difona
    tds =  document.css('body table')[6].css("tr")[0].css("td")

    if product_matched?(tds.first.content, product)
      matched_title = title_node.content
      #searh for price in the node
      price = tds.last.content.gsub(/\s{2,}/, "")

      self.host_with_price[grabber_site] = price
    end
  end

  def product_matched?(content, product)
    return content =~ /(#{product}|#{product.gsub('-','')})/ || content.gsub('-','') =~ /(#{product}|#{product.gsub('-','')})/
  end

  def get_default_filename
    return "result.csv"
  end

  def grabber_for_options
    {
      thiecom_details: {
        parent_node: 'body div.containerfullrow div.categorydetailsrow',
        title_node:  'div.font15.fontgray2.fontbold.paddingtop3',
        price_node:  'span.product_price_new_big'
      },

      funktechnik_bielefeld_details: {
        parent_node: 'body div.main-container div.col-main',
        title_node:  'div.page-title.category-title span',
        price_node:  'div.price-box span.regular-price span.price'
      }
    }
  end

  def get_key
    key = :funktechnik_bielefeld_details if grabber_site == :funktechnik_bielefeld
    key = :thiecom_details if grabber_site == :thiecom
    key = :difona_details if grabber_site == :difona

    return key
  end

  def fetch_product_url
    product_url = case grabber_site
                  when :thiecom
                    fetch_thiecom_product_url
                  when :funktechnik_bielefeld
                    fetch_funktechnik_bielefeld_product_url
                  when :difona
                    fetch_difona_product_url
                  end

    return product_url
  end

  def fetch_funktechnik_bielefeld_product_url
    # returns the json response
    search = open("http://www.funktechnik-bielefeld.de/ajaxsearch/?query=#{product}&store=1",
              "User-Agent" => "Mozilla/5.0 (Windows NT 6.2; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/32.0.1667.0 Safari/537.36"
            )
    search_string = search.readlines.first

    return JSON.parse(search_string)["data"].first
  rescue
    nil
  end

  def fetch_thiecom_product_url
    search = Nokogiri::HTML(open("http://www.thiecom.de/index.php?cl=smallsearch&searchparam=#{product}",
        "User-Agent" => "Mozilla/5.0 (Windows NT 6.2; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/32.0.1667.0 Safari/537.36"
      )
    )

    return search.css("table tr td a").first.attributes["href"].value
  rescue
    nil
  end

  def fetch_difona_product_url
    # "http://www.difona.de/details.php?&language=de&artmatch=DIFAT588VHF"
  rescue
    nil
  end

end

system("clear")

# urls = [
#   "http://www.thiecom.de/index.php?sid=56740ce86478d870dc4d0a623ba5002e&cl=details&anid=ca749ac40c12fbea6.16258412&listtype=search&searchparam=IC7600",
#   # "http://www.thiecom.de/index.php?sid=105b4ec3b7697e9dddc7bbecdce95791&cl=search&searchparam=ftdx1200",
#   "http://www.funktechnik-bielefeld.de/icom-ic-7600.html"
#   # "http://www.funktechnik-bielefeld.de/catalogsearch/result/?q=FT-DX5000"
# ]

products = [
    { name: "FTDX-1200" }, { name: "FTDX-5000" }, { name: "X-50N" },
    { name: "IC-7600" },{ name: "TS-480SAT" }
  ]

CSV.open("result.csv", "wb") do |csv|
  csv << ["Product", "thiecom", "difona", "funktechnik-bielefeld"]

  products.each do |product|
    grabber = Grabber.new(
        product:      product[:name],
        csv:          csv
      )

    grabber.parse
  end
end