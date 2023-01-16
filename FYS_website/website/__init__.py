# Module Imports
from flask import Flask, render_template, request, session, redirect, url_for, flash
import mariadb
import sys
import os
import subprocess

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
        try:
            query = "SELECT * FROM Persoon WHERE Naam = %s AND Ticketnummer = %s;"
            ticket_number = request.form.get('ticket_number')
            checkbox_terms = request.form.get('checkbox_terms')
            name = request.form.get('name')
            cur.execute(query, (name, ticket_number, ))
            name, ticket_number_validator, flight_number, destination, departure = cur.fetchone()
            session["Name"], session["ticket_number"], session["flight_number"], session["destiantion"], session["departure"] = name, ticket_number_validator, flight_number, destination, departure
        except:
            name = False
        if checkbox_terms == "on":
            if name:
                if ticket_number == ticket_number_validator:
                    session["login"] = "Yes"
                    try:
                        subprocess.call(["sudo", "iptables", "-t", "nat", "-I", "PREROUTING", "-s", f"{request.remote_addr}", "-j", "ACCEPT"])
                    except:
                        return redirect(url_for("home"))
                    return redirect(url_for("home"))
                else:
                    flash("Name or Ticketnumber is incorrect!")
            else:
                flash("Name or Ticketnumber is incorrect!")
        else:
            flash("Please accept the Terms & Conditions")

    return render_template("login.html")

# Logout page
@app.route("/logout")
def logout():
    subprocess.call(["sudo", "iptables", "-t", "nat", "-D", "PREROUTING", "-s", f"{request.remote_addr}", "-j", "ACCEPT"])
    session.clear()
    flash("You are logged out.")
    return redirect('login')

# Media page
@app.route('/media')
def media():
    return render_template('media.html')

# Terms and Conditions page
@app.route('/terms')
def terms():
    return render_template('terms.html')


if __name__ == "__main__":
    app.run()

