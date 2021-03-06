#***********************************************************************************************************
# Copyright BallotPath 2014
# Developed by Matt Clyde, Andrew Erland, Shawn Forgie, Andrew Hobbs, Kevin Mark, Darrell Sam, Blake Clough
# Open source under GPL v3 license (https://github.com/mclyde/BallotPath/blob/v0.3/LICENSE)
#***********************************************************************************************************

from flask import render_template, flash, redirect, url_for, jsonify, Response, request
from sqlalchemy.sql import text
from app import app, db, models
import json
from viewsd import office, office_holder, district, election_division, upload

@app.route("/")
@app.route("/index")
def index():
    return '<a href="'+url_for('get_offices', latitude=45.514032, longitude=-122.625468)+'">Try looking for Offices for latitude 45.514032 and longitutde -122.625468</a><br /><a href="'+url_for('get_office', office_id=1)+'">Try looking for Office with id 1</a><br /><a href="'+url_for('get_districts')+'">Try looking for all Districts</a><br /><a href="'+url_for('get_district', district_id=5)+'">Try looking for District with id 5</a><br /><a href="'+url_for('bulkupload')+'">Try uploading a file</a>'
