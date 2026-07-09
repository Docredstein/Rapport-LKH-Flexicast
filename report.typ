//#import "@preview/typographix-polytechnique-reports:0.2.1" as template
#import "template/0.2.1/main.typ" as template
// Defining variables for the cover page and PDF metadata
// Main title on cover page
#let title = [Gestion des clés \ pour Flexicast]
// Subtitle on cover page
#let subtitle = "Rapport de stage de recherche"
// Logo on cover page
#let logo = image("icteam.png") // instead of none set to image("path/to/my-logo.png")
#let logo-horizontal = true // set to true if the logo is squared or horizontal, set to false if not
// Short title on headers
#let short-title = "Rapport de stage"
#let author = "Mateïs FRAMBOURT"
#let date-start = datetime(year: 2026, month: 03, day: 05)
#let date-end = datetime(year: 2026, month: 07, day: 05)
// Set to true for bigger margins and so on (good luck with your report)
#let despair-mode = false
#let first-line-indent-all = auto
#set text(fallback: true)
#set text(lang: "fr")

// Set document metadata
#set document(title: title, author: author, date: datetime.today())
#show: template.apply.with(despair-mode: despair-mode, first-line-indent-all: first-line-indent-all)

// Cover page
#template.cover(
  title,
  author,
  date-start,
  date-end,
  subtitle: subtitle,
  logo: logo,
  logo-horizontal: logo-horizontal,
)
#pagebreak()

// Acknowledgements
#heading(level: 1, numbering: none, outlined: false)[Remerciements]
Je tiens à remercier Olivier BONAVENTURE, qui a été mon tuteur pendant ce stage, pour sa bonne humeur, sa sympathie et

Je souhaite d'autre part remercier Louis NAVARE pour son
#pagebreak()

// Executive summary
#heading(level: 1, numbering: none, outlined: false)[Abstract]
#lorem(300)
#pagebreak()

// Table of contents
#outline(title: [index], indent: 1em, depth: 2)

// Defining header and page numbering (will pagebreak)
#show: template.apply-header-footer.with(short-title: short-title)


// Introduction
#heading(level: 1)[Introduction]

  Les services de diffusion de vidéo en direct fonctionnent sur le principe de la diffusion d'un même contenu à plusieurs receveurs. Cependant, la diffusion est majoritairement réalisée avec un routage unicast (1 vers 1)@Livenet or certain contenu requierent le chiffrement de ce flux, par exemple pour des contenus payant. L'unicast implique donc que le serveur chiffre séparément pour chaque receveurs et ce, pour chaque paquet. Cela entraine un coût calculatoire important, par exemple le chiffrement d'un flux pour 400 receveurs sature le serveur relativement à un flux UDP pur qui n'implique pas de cout mesurable (figure 5)@Flexicast. 

  Dans ce sens, l'utilisation d'une diffusion en multicast (1 vers n), permettrait théoriquement de ne chiffrer qu'une fois chaque paquet. Dans cette optique, Flexicast (#emph("Flexi")ble Multi#emph("cast")) @Flexicast permet d'offrir une communication chiffrée multicast. 
  Cependant, à la rédaction de ce rapport, la spécification Flexicast ne spécifie pas encore de protocole pour la rotation de clé. Le flux est chiffré avec une clé statique. Les receveurs peuvent donc déchiffrer les paquets émis avant qu'ils aient rejoint le flux et après en être parti. Ainsi, Flexicast ne fournit pas de confidentialité persistante (_Perfect Forward Secrecy_) @secDef ce qui est nécessaire, par exemple, pour de la diffusion de contenu payant (Un utilisateur ne peut avoir accès au service que pendant qu'il paye). Il faut donc changer la clé dès qu'un utilisateur rejoint ou quitte l'arbre. Une méthode efficace de rotation de clé est donc nécessaire. Ce rapport propose une implémentation de rotation de clé basée sur la Hiérarchie Logique de Clé (_Logical Key Hierarchy_ ou LKH) @cannetiMulticast pour Flexicast. 

== Contexte
=== confidentialité persistante
La confidentialité persistante est définie dans @secDef comme la résistance à la découverte d'une clé privé sans compromettre les paquets précédents. 
=== QUIC
QUIC @RFCQuic est un protocole de couche 4 modulaire, léger, fiable et chiffré. Celui-ci repose sur de l'UDP. Les caractéristique remarquable de QUIC pour ce rapport sont : 
- Un datagramme UDP peut contenir plusieurs paquets QUIC
- Un paquet QUIC peut contenir plusieurs _frame_ QUIC et est chiffré et authentifié par une clé symétrique. 
- Une frame QUIC est l'unité de donnée contenant les données application et les données de controle. 

=== QUIC Multipath 
QUIC Multipath (QUIC-MP) @Multipath est une extension de QUIC ajoutant la possibilité pour une connexion QUIC d'avoir plus chemin réseau. Les caractéristiques notables 
dans le cadre de ce rapport sont : 
- Une connexion QUIC peut avoir plusieurs chemin réseau
- Les chemins réseau peuvent être unidirectionnel
- les acknowledgements peuvent être envoyé sur un chemin réseau indépendament du chemin réseau de réception grâce au frames PATH_ACK qui specifient le chemin où a été reçu le paquet. 
=== Flexicast 
#figure(
  image("Flexicast_basic.svg"),
  caption: "Organisation des chemins réseaux d'un flot Flexicast"
)

Flexicast (#emph("Flexi")ble Multi#emph("cast")) @Flexicast est une extension de QUIC et QUIC-MP utilisant les chemins réseau additionnel de QUIC-MP pour permettre une communication multicast. Chaque client (utilisant Flexicast) possède 2 chemins réseau :
- un chemin unicast bidirectionnel chiffré par la clé négociée sans différence relativement au QUIC standard 
- un chemin multicast unidirectionnel du serveur vers le client chiffré avec une clé de session (notée $K_s$) envoyée par le serveur sur le chemin unicast. 
Les acknowledgements sont envoyés uniquement sur le chemin unicast. 
Le processus standard pour rejoindre un flot Flexicast procède de la manière suivante (détaillé dans @FlexicastClientStateMachine): 
- Le client se connecte en unicast au serveur (Il y acquiert la clé de communication unicast)
- Le serveur propose un ou des flots Flexicast (Avec une frame "MC_ANNOUNCE" )
- Le client anonce vouloir rejoindre un flot (Avec une frame "MC_STATE(join)")
- Le serveur envoit la clé de session par l'unicast (Avec une frame "MC_KEY")
-  Le client confirme avoir rejoint le flot (avec une frame "MC_STATE")
- Le client peut partir ou être expulsé par le serveur du flot Flexicast (par une frame "MC_STATE")


=== Flexicast Quiche
#figure(
  image("schéma_fcquiche_louis.png"),
  caption: [Organisation des taches tokio d'un serveur Flexicast Quiche (directement issue de @Flexicast)]
  

)
Flexicast Quiche@FlexicastGithub  est une implémentation de Flexicast (client et serveur) en rust#box(image("rust.png",height: 0.5em, ),  baseline: 0.25em)@rustLogo se basant sur l'implémentation de QUIC Quiche de Cloudflare et la librarie Tokio@Tokio pour assurer l'exécution multitache. Tokio est centré sur l'utilisation de tâches qui communiquent par passation de message. Dans Flexicast Quiche, les catégories de taches sont réparties en : 
- "FC_Flow" (Flexicast flow) : Gère le flux sur l'arbre multicast, communique uniquement avec contrôleur racine
- "Controller" : Gère la liaison Unicast-Flexicast. Séparé en 2 sous-catégorie pour permettre une scalabilité horizontale en 
  - un unique contrôleur racine (côté multicast), informe les contrôleur feuille des paquets QUIC envoyés sur le flux multicast
  - un ensemble de contrôlleur feuille (côté unicast), aggrège les acknowledgements des chemins unicasts
- "UC" (Unicast) : Un ensemble de controlleur, chacun gère une unique connection QUIC unicast avec un client et peut communiquer avec un unique contrôleur feuille.  
La synchronisation entre les chemins unicasts et le flot Flexicast est réalisée par un message envoyé périodiquement depuis le "FC_Flow" informant les contrôleur du dernier numéro de paquet envoyé. 
Lorsqu'un client choisit de rejoindre le flot Flexicast, un message annoncant l'arrivée d'un nouveau client est propagé depuis les connexions UC vers les controleur feuille. 
#pagebreak()
= État de l'art
Le problème est appellé le chiffrement de diffusion (Broadcast Encryption)@BroadcastEncryption. Une source souhaite diffuser une contenu à un set de receveurs dynamiques. Il est possible que d'autre receveurs puissent recevoir tous les messages sur le canal mais ils ne doit pas être possible pour ces receveurs de déchiffrer le contenu. Pour la suite, le nombre de receveurs privilégié (RP) sera noté $n$ et l'ensembles des receveurs R. 
== Solution "Naïve"
=== Simili-unicast
La première solution @BroadcastEncryption est d'associer une clé par RP et de dupliquer le contenu n fois pour le chiffrer avec chaque clé. Cette solution est effectivement celle qui est utilisé sans multicast. La quantité de donnée à envoyer est linéaire relativement à $n$ et nécessite $n$ chiffrement. Cela résulte en une consommation processeur suffisante pour saturer dès $n=400$ dans la baseline pour le test de Flexicast @Flexicast. 
=== Solution sans message @BroadcastEncryption
Une solution pour limiter le nombre de message est de considérer qu'il est uniquement nécessaire d'assurer le chiffrement de diffusion pour un nombre de receveur ennemi (donc non privilégié) <=k⋅ C'est ainsi qu'est défini la k-résilience. Une méthode (théoriquement) simple consiste à créer un ensemble de clé et de les distribuer en considérant tout les sous-ensembles de R de cardinal<=k et de donner une clé pour chaque complémentaires de ces ensembles. De cette manière il est possible de construire une clé de session k-résiliente. Cependant, le coût mémoire de cette solution est exponentielle en k. De plus, il est _théoriquement_ possible pour un flot Flexicast d'avoir une quantité infinie de RP et donc aussi de récepteur ennemi. Ainsi, la k-résilience n'est pas suffisante 

== Solution à arbres binaires
#figure(
  image("tree_A32.svg"),
  caption: "Arbre binaire, les utilisateurs sont les nombres rouges et les id de clés les numéros sous les noeuds "
)<Arbre_binaire>
Dans l'optique de réduire le nombre de message, il est possible d'enregistrer les utilisateurs dans un arbre binaire pour lequel chaque noeud est associé à une clé. De cette manière, il est possible d'envoyer un message en multicast directement à un sous ensemble des utilisateurs enregistrés et ce pour un coût mémoire relativement limité pour le receveur. 


=== Receveurs sans état
La littérature propose des méthodes @TraitorTracing@LSD pour permettre d'assurer le chiffrement de la diffusion sans changer l'état des RP. Ces méthodes fonctionnent sur la création d'arbres binaires et la séléction de sous-arbres recouvrants. Ces méthodes permettent aussi le traçage de traitre qui consiste en l'identification d'un potentiel "traitre" qui rediffuserait le contenu. Ces méthodes n'utilisent pas de clé de session mais un ensemble de clé à utiliser comme en simili-unicast.

==== Sous-arbre complet @TraitorTracing
Un arbre binaire de clé est généré et, pour chaque utilisateur révoqué, les noeuds frêre du chemin de l'utiisateur jusqu'à la racines sont notés. (par exemple, dans @Arbre_binaire, si l'utilisateur 1 est révoqué, les noeuds [33,17,9,5,3] sont notés). En répétant cette opération pour chaque utilisateur révoqué, une collection de sous-arbres recouvrants les RP est créé. Ensuite le message est chiffré avec une clé de session K qui est chiffrée une fois avec chaque clé associée à une racine des sous-arbres de la collection. Le message final est 

$ [id_1,...,id_l,E_(L_(id_1))(K),...E_(L_(id_l))(K),E_K (M)] $ 
avec $id_i$, les identifiants des clés $L_(id_i)$, E_A(B) la fonction de chiffrement de B par la clé A et M le contenu à diffuser.
\ En notant $r$ le nombre de RP révoqués, la taille du header nécessaire est bornée par $r log(n/r)$ pour $log(n)$ clé stocké par chaque receveur @TraitorTracing. 
==== Différence de sous ensembles @TraitorTracing
Cette méthode est très similaire à la précédente, l'objectif est de trouver une collection d'ensemble minimale recouvrant exactement les RP. Dans cette méthode, les ensembles considérés sont plus flexible et sont défini comme la différence de sous arbres. C'est à dire sous la forme S(i,j), le sous-arbres ayant pour racine i mais n'appartient pas au sous-arbre de racine j. Par exemple, pour @Arbre_binaire, $S(4,9)$ contient les receveurs $[1,17,9,25]$. 
Il est possible, moyenant une création de clé décrite dans @TraitorTracing de réduire la taille du header à une borne de $2r -1$ au coût d'un stockage de $(log(n))^2/2$
#pagebreak()

= Annexe
#figure(
  image("ClientSideStateMachine.svg"), 
  caption: "Machine à état du client Flexicast"
)<FlexicastClientStateMachine>
#pagebreak()

#bibliography("bib.yml")
