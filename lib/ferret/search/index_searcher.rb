module Ferret::Search

  # Implements search over a single IndexReader.
  # 
  # Applications usually need only call the inherited @link #search(Query)end
  # or @link #search(Query,Filter)endmethods. For performance reasons it is 
  # recommended to open only one IndexSearcher and use it for all of your searches.
  class IndexSearcher
    include Ferret::Index

    attr_accessor :similarity, :reader

    # Creates a searcher searching the index in the provided directory. 
    #
    # You need to pass one argument which should be one of the following:
    #
    #   * An index reader which the searcher will search
    #   * A directory where the searcher will open an index reader to search
    #   * A string which represents a path to the directory to be searched
    #
    def initialize(arg)
      if arg.is_a?(IndexReader)
        @reader = arg
      elsif arg.is_a?(Ferret::Store::Directory)
        @reader = IndexReader.open(arg, false)
      elsif arg.is_a?(String)
        @dir = Ferret::Store::FSDirectory.new(arg, false)
        @reader = IndexReader.open(@dir, true)
      else
        raise ArgumentError, "Unknown argument passed to initialize IndexReader"
      end

      @similarity = Similarity.default
    end
    
    # IndexSearcher was constructed with IndexSearcher(r).
    # If the IndexReader was supplied implicitly by specifying a directory, then
    # the IndexReader gets closed.
    def close()
      @reader.close()
    end

    # Expert: Returns the number of documents containing +term+.
    # Called by search code to compute term weights.
    # See IndexReader#doc_freq
    def doc_freq(term)
      return @reader.doc_freq(term)
    end

    # Expert: For each term in the terms array, calculates the number of
    # documents containing +term+. Returns an array with these
    # document frequencies. Used to minimize number of remote calls.
    def doc_freqs(terms)
      result = Array.new(terms.length)
      terms.each_with_index {|term, i| result[i] = doc_freq(term)}
      return result
    end

    # Expert: Returns the stored fields of document +i+.
    #
    # See IndexReader#get_document
    def doc(i)
      return @reader.get_document(i)
    end

    # Expert: Returns one greater than the largest possible document number.
    # Called by search code to compute term weights.
    # See IndexReader#max_doc
    def max_doc()
      return @reader.max_doc()
    end

    # Creates a weight for +query+
    # returns:: new weight
    def create_weight(query)
      return query.weight(self)
    end

    # The main search method for the index. You need to create a query to
    # pass to this method. You can also pass a hash with one or more of the
    # following; {filter, num_docs, first_doc, sort}
    #
    # query::     The query to run on the index
    # filter::    filters docs from the search result
    # first_doc:: The index in the results of the first doc retrieved.
    #             Default is 0
    # num_docs::  The number of results returned. Default is 10
    # sort::      An array of SortFields describing how to sort the results.
    def search(query, options = {})
      filter = options[:filter]
      first_doc = options[:first_doc]||0
      num_docs = options[:num_docs]||10
      sort = options[:sort]

      if (num_docs <= 0)  # nil might be returned from hq.top() below.
        raise ArgumentError, "num_docs must be > 0 to run a search"
      end

      scorer = query.weight(self).scorer(@reader)
      if (scorer == nil)
        return TopDocs.new(0, [])
      end

      bits = (filter.nil? ? nil : filter.bits(@reader))
      if (sort)
        fields = sort.is_a?(Array) ? sort : sort.fields
        hq = FieldSortedHitQueue.new(@reader, fields, num_docs + first_doc)
      else
        hq = HitQueue.new(num_docs + first_doc)
      end
      total_hits = 0
      min_score = 0.0
      scorer.each_hit() do |doc, score|
        if score > 0.0 and (bits.nil? or bits.get(doc)) # skip docs not in bits
          total_hits += 1
          if hq.size < num_docs or score >= min_score 
            hq.insert(ScoreDoc.new(doc, score))
            min_score = hq.top.score # maintain min_score
          end
        end
      end

      score_docs = Array.new(hq.size)
      if (hq.size > first_doc)
        score_docs = Array.new(hq.size - first_doc)
        first_doc.times { hq.pop }
        (hq.size - 1).downto(0) do |i|
          score_docs[i] = hq.pop
        end
      else
        score_docs = []
        hq.clear
      end

      return TopDocs.new(total_hits, score_docs)
    end

    # Accepts a block and iterates through all of results yielding the doc
    # number and the score for that hit. The hits are unsorted. This is the
    # fastest way to get all of the hits from a search. However, you will
    # usually want your hits sorted at least by score so you should use the
    # #search method.
    def search_each(query, filter = nil)
      scorer = query.weight(self).scorer(@reader)
      return if scorer == nil
      bits = (filter.nil? ? nil : filter.bits(@reader))
      scorer.each_hit() do |doc, score|
        if score > 0.0 and (bits.nil? or bits.get(doc)) # skip docs not in bits
          yield(doc, score)
        end
      end
    end

    # rewrites the query into a query that can be processed by the search
    # methods. For example, a Fuzzy query is turned into a massive boolean
    # query.
    #
    # original:: The original query to be rewritten.
    def rewrite(original)
      query = original
      rewritten_query = query.rewrite(@reader)
      while query != rewritten_query
        query = rewritten_query
        rewritten_query = query.rewrite(@reader)
      end
      return query
    end

    # Returns an Explanation that describes how +doc+ scored against
    # +query+.
    # 
    # This is intended to be used in developing Similarity implementations,
    # and, for good performance, should not be displayed with every hit.
    # Computing an explanation is as expensive as executing the query over the
    # entire index.
    def explain(query, doc)
      return query.weight(self).explain(@reader, doc)
    end
  end
end
