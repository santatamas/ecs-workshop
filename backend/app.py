from flask import Flask, render_template
import socket
import requests
import boto3
app = Flask(__name__)
servicediscovery = boto3.client("servicediscovery")


@app.route("/ping")
def ping():
    return "", 200


@app.route("/")
def hello():
    services = []
    namespaces = servicediscovery.list_namespaces()
    namespace_obj = [namespace for namespace in namespaces.get('Namespaces', [])]
    
    for namespace in namespace_obj:
        resp = servicediscovery.list_services(Filters=[{'Name': 'NAMESPACE_ID', 'Values': [namespace['Id']]}])
        service_obj = [service for service in resp.get('Services', []) if service['Name'] != "backend"]

        for service in service_obj:
            addr = "Can't resolve healthy instance(s)"
            text = ""
            try:
              addr = socket.gethostbyname(service['Name']+'.'+namespace['Name'])
              if service['Name'] == "worker": 
                text = "Service says: " + requests.get("http://"+service['Name']+'.'+namespace['Name']).content.decode("utf-8")
            except:
              print("An exception occurred while trying to resolve host IP") 
            
            services.append({
                'namespace': namespace['Name'],
                'name': service['Name'],
                'addr': addr,
                'num_hosts': len(servicediscovery.list_instances(ServiceId=service['Id'])['Instances']),
                'text': text
            })
    return render_template("index.html", services=services)

if __name__ == "__main__":
    app.run(debug=True, host='0.0.0.0', port=80)
