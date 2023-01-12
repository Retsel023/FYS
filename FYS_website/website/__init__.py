# Module Imports
from flask import Flask, Blueprint, render_template, request, session, redirect, url_for, flash
import mariadb
import sys
import os

app = Flask(__name__)
app.config['SECRET_KEY'] = os.urandom(23)

# Connect to MariaDB Platform
try:
    conn = mariadb.connect(
        user="Flightmanager",
        password="SecretKey##11WXX",
        host="127.0.0.1",
        port=3306,
        database="FYS"
    )
    
except mariadb.Error as e:
    print(f"Error connecting to MariaDB Platform: {e}")
    sys.exit(1)

# Get Cursor
cur = conn.cursor()

# home page
@app.route('/')
def home():
    try:
        if session["login"] == "Yes":
            return render_template("home.html")
        else:
            flash("Please login first")
    except:
        return redirect("login")
    return redirect("login")
    
# login page 
@app.route('/login', methods=['GET', 'POST'])
def login():
    session["login"] = "No"
    if request.method == 'POST':
        query_user = "SELECT Naam FROM Persoon WHERE Naam = %s;"
        query_ticket = "SELECT Ticketnummer FROM Persoon WHERE Naam = %s;"
        # Getting values from the login form
        ticket_number = request.form.get('ticket_number')
        checkbox_terms = request.form.get('checkbox_terms')
        Name = request.form.get('username')
        cur.execute(query_user, (Name, ))
        user = cur.fetchone()
        cur.execute(query_ticket, (Name, ))
        ticket_validation = cur.fetchone()
        session["Name"], session["Ticket_number"] = Name, ticket_number
        if checkbox_terms == "on":
            if user:
                print("enter user")
                if ticket_number == ticket_validation[0]:
                    session["login"] = "Yes"
                    return redirect(url_for("home"))
                else:
                    flash("Name or Ticketnumber is incorrect!")
            else:
                flash("Name or Ticketnumber is incorrect!")
        else:
            flash("Please accept the Terms & Conditions")

    return render_template("login.html")

# media page
@app.route('/media')
def media():
    return render_template('media.html')

# Terms and Conditions page
@app.route('/terms')
def terms():
    return render_template('terms.html')

if __name__ == "__main__":
    app.run()
