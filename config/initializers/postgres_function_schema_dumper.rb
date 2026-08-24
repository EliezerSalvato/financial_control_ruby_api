module PostgresFunctionSchemaDumper
  private

  def types(stream)
    super
    postgres_functions(stream)
  end

  def postgres_functions(stream)
    definitions = @connection.select_values(<<~SQL)
      SELECT pg_get_functiondef(pg_proc.oid)
        FROM pg_proc
        JOIN pg_namespace
          ON pg_namespace.oid = pg_proc.pronamespace
   LEFT JOIN pg_depend
          ON pg_depend.objid = pg_proc.oid AND pg_depend.deptype = 'e'
       WHERE pg_namespace.nspname = ANY (current_schemas(false))
         AND pg_proc.prokind IN ('f', 'p')
         AND pg_depend.objid IS NULL
       ORDER BY pg_proc.proname, pg_get_function_identity_arguments(pg_proc.oid)
    SQL

    return if definitions.empty?

    stream.puts "  # Custom PostgreSQL functions defined in this database."
    definitions.each do |definition|
      stream.puts "  execute <<-'SQL'"
      definition.each_line { |line| stream.puts "    #{line.rstrip}" }
      stream.puts "  SQL"
      stream.puts
    end
  end
end

ActiveSupport.on_load(:active_record_postgresqladapter) do
  ActiveRecord::ConnectionAdapters::PostgreSQL::SchemaDumper.prepend(PostgresFunctionSchemaDumper)
end
