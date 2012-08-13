(defproject blobber-migration "0.1.0-SNAPSHOT"
  :description "Migrate from a PostgreSQL database to a filesystem-trie."
  :url "https://github.com/craig-ludington/blobber-migration"
  :license {:name "Eclipse Public License"
            :url "http://www.eclipse.org/legal/epl-v10.html"}
  :dependencies [[org.clojure/clojure "1.4.0"]
                 [postgresql/postgresql "8.4-702.jdbc4"]
                 [filesystem-trie "0.1.0-SNAPSHOT"]
                 [org.clojure/java.jdbc "0.2.3"]])
