import os
from flask import Blueprint, request, jsonify
from db import mysql

classify_bp = Blueprint('add', __name__, url_prefix='/add')