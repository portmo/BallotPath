----------------------------------------------------------
-- Bulk csv import procedure for districts and election --
-- divisions                                            --
--                                                      --
-- Imports a template csv delimited by '|' located      --
-- in /tmp/import/ and identified as a parameter passed --
-- in by the caller                                     --
--                                                      --
-- On import this procedure does validation and error   --
-- reporting. Any errors are flagged and written to a   --
-- csv located in /tmp/import/errors/ the resulting     --
-- filename is returned to the caller.                  --
--                                                      --
-- Authored by: Shawn Forgie                            --
-- For: BallotPath                                      --
-- Date: July 8, 2014                                   --
----------------------------------------------------------

CREATE OR REPLACE FUNCTION bp_import_dist_elec_div_csv_to_staging_tables(filename character varying)
  RETURNS character varying AS
$BODY$
  DECLARE
    input_file character varying := format(E'/tmp/import/%s', filename);
    outname character varying := format(E'bad_inserts_%s.csv', (SELECT * FROM to_char(current_timestamp, 'YYYY-MM-DD-HH24:MI:SS')));
    output_file character varying := format(E'/tmp/import/errors/%s', outname);
    districts CURSOR FOR SELECT * FROM bulk_staging_districts;
    tmp integer;
    ed_id integer := NULL;
  BEGIN

  CREATE TEMPORARY TABLE bulk_staging_districts (
	  election_div_name character varying(125),
	  phys_addr1 character varying(100),
	  phys_addr2 character varying(100),
	  phys_addr_city character varying(35),
	  phys_addr_state character(2),
	  phys_addr_zip character(5),
	  mail_addr1 character varying(100),
	  mail_addr2 character varying(100),
	  mail_addr_city character varying(35),
	  mail_addr_state character(2),
	  mail_addr_zip character(5),
	  election_div_phone character varying(15),
	  fax character varying(15),
	  election_div_website text,
	  election_div_doc_name character varying(125),
	  election_div_doc_link text,
	  district_state character(2),
	  district_name character varying(125),
	  level_name character varying(12),
	  bad_insert_flag bit default B'0',					-- 0 := good, 1 := bad
	  message text
  )ON COMMIT DROP;

  EXECUTE format('
  	Copy bulk_staging_districts ( district_name
					, district_state
					, level_name
					, election_div_name
					, phys_addr1
					, phys_addr2
					, phys_addr_city
					, phys_addr_state
					, phys_addr_zip
					, mail_addr1
					, mail_addr2
					, mail_addr_city
					, mail_addr_state
					, mail_addr_zip
					, election_div_phone
					, fax
					, election_div_website
					, election_div_doc_name
					, election_div_doc_link)
  FROM %L
  WITH
    DELIMITER ''|''
    NULL ''''
    CSV HEADER', input_file);

-- Insert requires a district state, name and election division name (potentially state also?)
-- Flag district entries that do not have enough information (might be done by api?)
UPDATE bulk_staging_districts
	SET bad_insert_flag = B'1'
		, message = 'Expected non-empty string in district_state, district_name and election_div_name! and phys_addr_state'
	WHERE district_name = ''
		  OR district_state = ''
		  OR election_div_name = ''
		  OR phys_addr_state = '';

FOR dist IN districts LOOP
	-- Do not insert if flagged
	IF (dist.bad_insert_flag <> B'1') THEN

		--Retrieve existing election_div_id if it exists
		SELECT ed.id into ed_id FROM election_div ed WHERE ed.name = dist.election_div_name and ed.phys_addr_state = dist.phys_addr_state;

		--IF the election division in the state is found do not re-insert
		IF (ed_id IS NULL) THEN
			with tmp as (INSERT into election_div (name
								  , phys_addr_addr1
								  , phys_addr_addr2
								  , phys_addr_city
								  , phys_addr_state
								  , phys_addr_zip
								  , mail_addr_addr1
								  , mail_addr_addr2
								  , mail_addr_city
								  , mail_addr_state
								  , mail_addr_zip
								  , phone
								  , fax
								  , website)
							VALUES( dist.election_div_name
								  , dist.phys_addr1
								  , dist.phys_addr2
								  , dist.phys_addr_city
								  , dist.phys_addr_state
								  , dist.phys_addr_zip
								  , dist.mail_addr1
								  , dist.mail_addr2
								  , dist.mail_addr_city
								  , dist.mail_addr_state
								  , dist.mail_addr_zip
								  , dist.election_div_phone
								  , dist.fax
								  , dist.election_div_website)
								  RETURNING id)
			SELECT * into ed_id FROM tmp LIMIT 1;
		END IF;

		--Do not reinsert a district with this election division
		IF NOT EXISTS (SELECT * FROM district WHERE name = dist.district_name and state = dist.district_state and election_div_id = ed_id) THEN
			-- link districts
			INSERT into district (state
				  , name
				  , level_id
				  , election_div_id)
  			  VALUES (dist.district_state
  					, dist.district_name
  					, (SELECT l.id FROM level l WHERE l.name = dist.level_name)
  					, ed_id);
		END IF;

  		-- link election div docs
		IF (dist.election_div_doc_name <> '' or dist.election_div_doc_link <> '') THEN
			IF(dist.election_div_doc_name <> '' and dist.election_div_doc_link <> '') THEN
			    -- do not reinsert documents
			    IF NOT EXISTS (SELECT * FROM election_div_docs WHERE name = dist.election_div_doc_name and link = dist.election_div_doc_link and election_div_id = ed_id) THEN
				INSERT into election_div_docs (name, link, election_div_id)
	    			VALUES (dist.election_div_doc_name, dist.election_div_doc_link, ed_id);
	    		    ELSE
	    		       UPDATE bulk_staging_districts
					SET bad_insert_flag = B'1'
						, message = 'Duplicate election division document detected!'
				WHERE CURRENT OF districts;
			    END IF;
	    		ELSE
				UPDATE bulk_staging_districts
					SET bad_insert_flag = B'1'
						, message = 'Encountered empty value in office document fields!'
				WHERE CURRENT OF districts;
			END IF;

  		END IF;		
	END IF;
END LOOP;

  -- Write flagged entries to a csv for error reporting
  IF((SELECT COUNT(*) FROM bulk_staging_districts WHERE bad_insert_flag = B'1') > 0) THEN
  	EXECUTE format('
  		COPY (SELECT * FROM bulk_staging_districts WHERE bad_insert_flag = B''1'')
  		TO %L
  		WITH
		    DELIMITER ''|''
		    NULL ''--''
		    CSV HEADER', output_file);
	RETURN outname;
  END IF;

RETURN '';

END;
$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100;