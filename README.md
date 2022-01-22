# Azure Gateway Load Balancer tests
This repo contains PoC to learn traditional NVA integration vs. Azure Gateway Load Balancer.

Initialy I focus on North-South traffic.

## No security
This reference example showcase web server farm with no security NVA implemented.

Inbound architecture:
Public LB -> VM with web application

Outbound architecture:
VM with web application -> Public LB

Key aspects:
- Developers are self sufficient - can see their own IP, LB rules
- No complex network topology needed

To deploy:

```
cd noSecurity
az bicep build -f main.bicep && az deployment sub create --template-file main.json -l westeurope
```

## Traditional security
In this scenario I take traditional approach to deploy network security inspection NVA so when users access public endpoint traffic goes via NVA.

Options:
- Single-NVA solution is easy, but single point of failure
- Active/Standby solution requires scripts to move public IP from one VM to another and rewrite UDR during switchover
- Most popular solution is to use load balancers:
    - Public LB in front of NVAs is used to get users traffic therefore public IPs lives on LB. NVA can be in active/passive mode (= passive NVA will not respond to healthcheck probe) or active/active (all NVAs are active and traffic is dsitributed using 5-tuple hash)
    - Private LB in front of NVAs is used as next-hop for virtual machines in Azure using "HA ports" configuration
    - Since both LBs decide independently about traffic flows, there is potential for asymetry. Therefore in this mode NVA needs to SNAT for both outbound and inbound (VMs see NVAs as source IP, not public client IP)
- Well positioned for NVAs doing routing (eg. firewalls) or traffic termination (eg. proxies), not ideal for more passive scenarios (traffic analytics, IPS, DDoS, traffic recording)
  
Inbound architecture:
Public LB -> NVA -> Private LB of app via VNET peering -> VM with web application

Outbound architecture:
VM with web application -> Private LB of NVA via VNET peering -> NVA -> Outbound via Public LB of NVA

To deploy:

```
cd traditionalSecurity
az bicep build -f main.bicep && az deployment sub create --template-file main.json -l westeurope
```

## GW LB based security
In this scenario NVA is chained to traffic with no need to participate in routing. Note from application perspective there is almost no difference compared to "no security" scenario:

- There is Public LB in front of application as before, only one configuration is added (reference to gateway LB)
- Rules on Public LB are as before
- No need for VNET to be peered
- No need for routing modification (no UDRs)
- NVA VNET can be in different subscription, region or even tenant
- NVA is not modifying packets (no routing or NAT needed)
- Application VM see public source IP of client

Inbound architecture:
Public LB -> NVA -> Public LB -> VM with web application

Outbound architecture:
VM with web application -> Public LB -> NVA -> Outbound via Public LB(of application)

To deploy:

```
cd gwlbSecurity
az bicep build -f main.bicep && az deployment sub create --template-file main.json -l westeurope
```