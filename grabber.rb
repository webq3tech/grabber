require 'rubygems'

begin
  require 'nokogiri'
rescue Exception => e
  puts "It's seems nokogiri gem is not installed on your system.\n" +
       "Please run 'gem install nokogiri' and then run the script"

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
  attr_accessor :url, :urls, :product, :document, :grabber_site, :count, :query_hash,
                :csv, :index_value

  ################################
  # Class Object When Initialized
  ################################

  # Options will here take the hash which would contain
  # url, products etc.
  # url - will fetch the url
  # products - will look for the products and their price
  def initialize(options = {})
    self.count        = 0

    self.urls         = options[:urls]
    self.product      = options[:product]
    # self.query_hash   = CGI::parse(URI.parse(url).query) unless URI.parse(url).query.nil?
    # self.grabber_site = get_grabber_site
    self.csv          = options[:csv]
    self.index_value  = options[:index_value]
    # self.document     = fetch_url
  end

  ##########################
  # Public Methods
  ##########################
  def parse
    urls.each do |url|
      self.url          = url
      self.document     = fetch_url
      self.query_hash   = CGI::parse(URI.parse(url).query) unless URI.parse(url).query.nil?
      self.grabber_site = get_grabber_site

      parse_for grabber_site

      self.query_hash = nil
    end
  end

  ##########################
  # Private Methods
  ##########################
  private

  def fetch_url
    # puts "Grabbing URL - #{url}"
    return Nokogiri::HTML(open(url))
  end

  def get_grabber_site
    HOSTS.each do |host|
      return host.gsub("-", "_").to_sym if URI.parse(url).host =~ /#{host}/
    end

    return nil
  end

  def parse_for(grabber_for = nil)
    return nil if grabber_for.nil?

    key       = get_key.to_sym
    node_hash = grabber_for_options[key]

    fetch_product(node_hash)
  end

  def fetch_product(node_hash)
    document.css(node_hash[:parent_node]).each do |node|
      # Search for prodcut title
      node.css(node_hash[:title_node]).each_with_index do |title_node, index|

          if product_matched?(title_node.content, product)

            matched_title = title_node.content
            @count        += 1

            #searh for price in the node
            price = node.css(node_hash[:price_node])[index].content

            csv << [index_value, product, matched_title, price, url]
          end

      end
    end
  end

  def product_matched?(content, product)
    return content =~ /(#{product}|#{product.gsub('-','')})/ || content.gsub('-','') =~ /(#{product}|#{product.gsub('-','')})/
  end

  def get_default_filename
    # file = "thiecom_grabber_" + query_hash["cl"].first  if grabber_site == :thiecom
    # file = "funktechnik_bielefeld_detail"               if grabber_site == :funktechnik_bielefeld && query_hash.nil?
    # file = "funktechnik_bielefeld_search"               if grabber_site == :funktechnik_bielefeld && !query_hash.nil?

    file ||= "result"
    file += ".csv"

    return file
  end

  def grabber_for_options
    {
      thiecom_search: {
        parent_node: 'body div.containerfullrow div.categorydetailsrow',
        title_node:  'div.product_title_big a',
        price_node:  'span.product_price_new'
      },

      thiecom_details: {
        parent_node: 'body div.containerfullrow div.categorydetailsrow',
        title_node:  'div.font15.fontgray2.fontbold.paddingtop3',
        price_node:  'span.product_price_new_big'
      },

      difona: {
        parent_node: 'body div.containerfullrow div.categorydetailsrow',
        title_node:  'div.product_title_big a',
        price_node:  'span.product_price_new'
      },

      funktechnik_bielefeld_search: {
        parent_node: 'body div.main-container div.col-main',
        title_node:  'div.category-products ul.products-grid li.item h2.product-name a',
        price_node:  'div.category-products ul.products-grid li.item div.price-box span.regular-price span.price'
      },

      funktechnik_bielefeld_detail: {
        parent_node: 'body div.main-container div.col-main',
        title_node:  'div.page-title.category-title span',
        price_node:  'div.price-box span.regular-price span.price'
      }
    }
  end

  def get_key
    key = grabber_site.to_s + "_" + query_hash["cl"].first if grabber_site == :thiecom
    key = :funktechnik_bielefeld_detail if grabber_site == :funktechnik_bielefeld && query_hash.nil?
    key = :funktechnik_bielefeld_search if grabber_site == :funktechnik_bielefeld && !query_hash.nil?

    return key
  end

end

system("clear")

urls = [
  "http://www.thiecom.de/index.php?sid=d1213bfa6787f43bedf299c75a4d4801&cl=details&anid=aa1519f4c402aa215.43759963&listtype=search&searchparam=ftdx1200",
  "http://www.thiecom.de/index.php?sid=105b4ec3b7697e9dddc7bbecdce95791&cl=search&searchparam=ftdx1200",
  "http://www.funktechnik-bielefeld.de/yaesu-ft-dx5000.html",
  "http://www.funktechnik-bielefeld.de/catalogsearch/result/?q=FT-DX5000"
]

CSV.open("result.csv", "wb") do |csv|
  csv << ["Index", "Product", "Matched Title", "Price", "url"]

  products = ["FTDX-1200", "FTDX-5000", "X-50N", "IC-7600", "TS-480SAT"].each_with_index do |product, index|
    grabber = Grabber.new(
        urls:         urls,
        product:      product,
        index_value:  index + 1,
        csv:          csv
      )

    grabber.parse
  end
end