# frozen_string_literal: true

class SearchQueryTransformer < Parslet::Transform
  class Query
    attr_reader :should_clauses, :must_not_clauses, :must_clauses, :filter_clauses
    attr_reader :order_clauses

    def initialize(clauses)
      grouped = clauses.chunk(&:operator).to_h
      @should_clauses = grouped.fetch(:should, [])
      @must_not_clauses = grouped.fetch(:must_not, [])
      @must_clauses = grouped.fetch(:must, [])
      @filter_clauses = grouped.fetch(:filter, [])
      @order_clauses = grouped.fetch(:order, [])
    end

    def apply(search)
      should_clauses.each { |clause| search = search.query.should(clause_to_query(clause)) }
      must_clauses.each { |clause| search = search.query.must(clause_to_query(clause)) }
      must_not_clauses.each { |clause| search = search.query.must_not(clause_to_query(clause)) }
      filter_clauses.each { |clause| search = search.filter(**clause_to_filter(clause)) }
      order_clauses.each { |clause| search = search.order(**clause_to_order(clause)) }
      search.query.minimum_should_match(1)
    end

    private

    def clause_to_query(clause)
      case clause
      when TermClause
        # { multi_match: { type: 'most_fields', query: clause.term, fields: ['text', 'text.stemmed'] } }
        { match: { 'text.stemmed': {query: clause.term } } }
      when PhraseClause
        { match_phrase: { text: { query: clause.phrase } } }
      else
        raise "Unexpected clause type: #{clause}"
      end
    end

    def clause_to_filter(clause)
      case clause
      when PrefixClause
        if clause.present?
          if clause.terms.present? && clause.terms.size > 0
            return { terms: { clause.filter => clause.terms } }
          elsif clause.term.present?
            return { term: { clause.filter => clause.term } }
          end
        end

        {}
      else
        raise "Unexpected clause type: #{clause}"
      end
    end

    def clause_to_order(clause)
      case clause
      when PrefixClause
        { clause.filter => { order: clause.order } }
      else
        raise "Unexpected clause type: #{clause}"
      end
    end
  end

  class Operator
    class << self
      def symbol(str)
        case str
        when '+'
          :must
        when '-'
          :must_not
        when nil
          :should
        else
          raise "Unknown operator: #{str}"
        end
      end
    end
  end

  class TermClause
    attr_reader :prefix, :operator, :term

    def initialize(prefix, operator, term)
      @prefix = prefix
      @operator = Operator.symbol(operator)
      @term = term
    end
  end

  class PhraseClause
    attr_reader :prefix, :operator, :phrase

    def initialize(prefix, operator, phrase)
      @prefix = prefix
      @operator = Operator.symbol(operator)
      @phrase = phrase
    end
  end

  class PrefixClause
    attr_reader :filter, :operator, :term
    attr_reader :terms, :order

    def initialize(prefix, term, search_by)
      @operator = :filter
      case prefix
      when 'from'
        @filter = :account_id

        username, domain = term.gsub(/\A@/, '').split('@')
        domain           = nil if TagManager.instance.local_domain?(domain)
        account          = Account.find_remote!(username, domain)

        @term = account.id
      when 'from_domain'
        @filter = :account_domain

        @term = term
      when 'boosted'
        @filter = :boosted_by

        @term = search_by.id
      when 'favourited'
        @filter = :favourited_by

        @term = search_by.id
      when 'bookmarked'
        @filter = :bookmarked_by

        @term = search_by.id
      when 'by_following'
        @filter = :account_id

        @terms = Follow.where(account: search_by).select(:target_account_id).map(&:target_account_id)
        if @terms.empty?
          # 空だとなんかコケるのでとりあえず
          @terms = [0]
        end
      when 'by_follower'
        @filter = :account_id

        @terms = Follow.where(target_account: search_by).select(:account_id).map(&:account_id)
        if @terms.empty?
          @terms = [0]
        end
      when 'sort'
        @operator = :order

        case term
        when 'created-desc'
          @filter = :created_at
          @order = :desc
        when 'created-asc'
          @filter = :created_at
          @order = :asc
        when 'boosts-desc'
          @filter = :boosts_count
          @order = :desc
        when 'favourites-desc'
          @filter = :favourites_count
          @order = :desc
        else
          raise Mastodon::SyntaxError
        end
      else
        raise Mastodon::SyntaxError
      end
    end
  end

  rule(clause: subtree(:clause)) do
    prefix   = clause[:prefix][:term].to_s if clause[:prefix]
    operator = clause[:operator]&.to_s

    if clause[:prefix]
      PrefixClause.new(prefix, clause[:term].to_s, account)
    elsif clause[:term]
      TermClause.new(prefix, operator, clause[:term].to_s)
    elsif clause[:shortcode]
      TermClause.new(prefix, operator, ":#{clause[:term]}:")
    elsif clause[:phrase]
      PhraseClause.new(prefix, operator, clause[:phrase].is_a?(Array) ? clause[:phrase].map { |p| p[:term].to_s }.join(' ') : clause[:phrase].to_s)
    else
      raise "Unexpected clause type: #{clause}"
    end
  end

  rule(query: sequence(:clauses)) { Query.new(clauses) }
end
