CREATE APPLICATION ROLE app_admin;
CREATE APPLICATION ROLE app_user;
CREATE SCHEMA IF NOT EXISTS app_public;
GRANT USAGE ON SCHEMA app_public TO APPLICATION ROLE app_admin;
GRANT USAGE ON SCHEMA app_public TO APPLICATION ROLE app_user;
CREATE OR ALTER VERSIONED SCHEMA v1;
GRANT USAGE ON SCHEMA v1 TO APPLICATION ROLE app_admin;


CREATE PROCEDURE v1.register_single_callback(ref_name STRING, operation STRING, ref_or_alias STRING)
 RETURNS STRING
 LANGUAGE SQL
 AS $$
      BEGIN
      CASE (operation)
         WHEN 'ADD' THEN
            EXECUTE IMMEDIATE 'SELECT system$set_reference(?, ?)' USING (ref_name, ref_or_alias);
         WHEN 'REMOVE' THEN
            EXECUTE IMMEDIATE 'SELECT system$remove_reference(?)' USING (ref_name);
         WHEN 'CLEAR' THEN
            EXECUTE IMMEDIATE 'SELECT system$remove_reference(?)' USING (ref_name);
         ELSE
            RETURN 'Unknown operation: ' || operation;
      END CASE;
      RETURN 'Operation ' || operation || ' succeeds.';
      END;
   $$;
GRANT USAGE ON PROCEDURE v1.register_single_callback( STRING,  STRING,  STRING) TO APPLICATION ROLE app_admin;

CREATE OR REPLACE PROCEDURE app_public.start_app(poolname VARCHAR, whname VARCHAR)
    RETURNS string
    LANGUAGE sql
    AS $$
BEGIN
        EXECUTE IMMEDIATE 'CREATE SERVICE IF NOT EXISTS app_public.st_spcs
            IN COMPUTE POOL Identifier(''' || poolname || ''')
            FROM SPECIFICATION_FILE=''' || '/falkordb.yaml' || '''
            QUERY_WAREHOUSE=''' || whname || '''';
        GRANT USAGE ON SERVICE app_public.st_spcs TO APPLICATION ROLE app_user;
        GRANT SERVICE ROLE app_public.st_spcs!ALL_ENDPOINTS_USAGE TO APPLICATION ROLE app_user;

RETURN 'Service started. Check status, and when ready, get URL';
END;
$$;
GRANT USAGE ON PROCEDURE app_public.start_app(VARCHAR, VARCHAR) TO APPLICATION ROLE app_admin;

CREATE OR REPLACE PROCEDURE app_public.stop_app()
    RETURNS string
    LANGUAGE sql
    AS
$$
BEGIN
    DROP SERVICE IF EXISTS app_public.st_spcs;
END
$$;
GRANT USAGE ON PROCEDURE app_public.stop_app() TO APPLICATION ROLE app_admin;

CREATE OR REPLACE PROCEDURE app_public.app_url()
    RETURNS string
    LANGUAGE sql
    AS
$$
BEGIN
    SHOW ENDPOINTS IN SERVICE app_public.st_spcs;
    RETURN (SELECT "ingress_url" FROM TABLE (RESULT_SCAN (LAST_QUERY_ID())) WHERE "name" = 'app' LIMIT 1);
END
$$;
GRANT USAGE ON PROCEDURE app_public.app_url() TO APPLICATION ROLE app_admin;
GRANT USAGE ON PROCEDURE app_public.app_url() TO APPLICATION ROLE app_user;

CREATE OR REPLACE PROCEDURE app_public.falkordb_browser_url()
    RETURNS string
    LANGUAGE sql
    AS
$$
BEGIN
    SHOW ENDPOINTS IN SERVICE app_public.st_spcs;
    RETURN (SELECT "ingress_url" FROM TABLE (RESULT_SCAN (LAST_QUERY_ID())) WHERE "name" = 'falkordb-browser' LIMIT 1);
END
$$;
GRANT USAGE ON PROCEDURE app_public.falkordb_browser_url() TO APPLICATION ROLE app_admin;
GRANT USAGE ON PROCEDURE app_public.falkordb_browser_url() TO APPLICATION ROLE app_user;

CREATE OR REPLACE PROCEDURE app_public.falkordb_endpoint()
    RETURNS string
    LANGUAGE sql
    AS
$$
BEGIN
    SHOW ENDPOINTS IN SERVICE app_public.st_spcs;
    RETURN (SELECT "ingress_url" FROM TABLE (RESULT_SCAN (LAST_QUERY_ID())) WHERE "name" = 'falkordb' LIMIT 1);
END
$$;
GRANT USAGE ON PROCEDURE app_public.falkordb_endpoint() TO APPLICATION ROLE app_admin;
GRANT USAGE ON PROCEDURE app_public.falkordb_endpoint() TO APPLICATION ROLE app_user;

-- Graph Data Loading Procedure
CREATE OR REPLACE PROCEDURE app_public.load_graph(graph_name VARCHAR, nodes_ref VARCHAR, relations_ref VARCHAR)
    RETURNS string
    LANGUAGE sql
    AS
$$
DECLARE
    nodes_count NUMBER;
    relations_count NUMBER;
    result_msg VARCHAR;
BEGIN
    -- Count nodes from the referenced table  
    nodes_count := (EXECUTE IMMEDIATE 'SELECT COUNT(*) FROM REFERENCE(''' || nodes_ref || ''')');
    
    -- Count relationships from the referenced table  
    relations_count := (EXECUTE IMMEDIATE 'SELECT COUNT(*) FROM REFERENCE(''' || relations_ref || ''')');
    
    -- Build result message
    result_msg := 'Graph: ' || graph_name || ' | Nodes: ' || nodes_count || ' | Relations: ' || relations_count;
    
    RETURN result_msg;
END
$$;
GRANT USAGE ON PROCEDURE app_public.load_graph(VARCHAR, VARCHAR, VARCHAR) TO APPLICATION ROLE app_admin;
GRANT USAGE ON PROCEDURE app_public.load_graph(VARCHAR, VARCHAR, VARCHAR) TO APPLICATION ROLE app_user;
