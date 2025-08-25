--Setup Script - Run this first to set up roles, databases, and get repository URL
--This script sets up the infrastructure needed for the SPCS Native App

--Step 1 - Create NASPCS role and Grant Privileges
--these series of steps create and grant the naspcs role which will be our 'provider' role 
use role accountadmin;
create role if not exists naspcs_role;
grant role naspcs_role to role accountadmin;
grant create integration on account to role naspcs_role;
-- grant create compute pool on account to role naspcs_role;
grant create warehouse on account to role naspcs_role;
grant create database on account to role naspcs_role;
grant create application package on account to role naspcs_role;
grant create application on account to role naspcs_role with grant option;
grant bind service endpoint on account to role naspcs_role;

--Step 2 - Create SCPS_APP Database to Store Application Files and Container Images
--after creating the naspcs role we will switch to it and set up our environment 
--the spcs_app database will house our snowpark container services images 
--it will also be where we upload the required files to create a native app package
use role naspcs_role;
create database if not exists spcs_app;
create schema if not exists spcs_app.napp;
create stage if not exists spcs_app.napp.app_stage;
create image repository if not exists spcs_app.napp.img_repo;
create warehouse if not exists wh_nap with warehouse_size='xsmall';

--Step 3 - Create NAC role and Grant Privileges
--now that we've created our application package we need to set up a role to imitate a 'consumer' installing the native app
use role accountadmin;
create role if not exists nac;
grant role nac to role accountadmin;
create warehouse if not exists wh_nac with warehouse_size='xsmall';
grant usage on warehouse wh_nac to role nac with grant option;
grant imported privileges on database snowflake_sample_data to role nac;
grant create database on account to role nac;
grant bind service endpoint on account to role nac with grant option;
-- grant create compute pool on account to role nac;
grant create application on account to role nac;

--Step 5 - Get Image Repository URL
--once we've created the database to store our images and na files we can find the image repository url
use role naspcs_role;
show image repositories in schema spcs_app.napp;

--Setup completed! 
--The repository URL will be automatically extracted by the automation scripts.
