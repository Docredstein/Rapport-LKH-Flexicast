//#import "@preview/typographix-polytechnique-reports:0.2.1" as template
#import "template/0.2.1/main.typ" as template
// Defining variables for the cover page and PDF metadata
// Main title on cover page
#let title = [Gestion des clés \ pour flexicast]
// Subtitle on cover page
#let subtitle = "Rapport de stage de recherche"
// Logo on cover page
#let logo = image("icteam.png") // instead of none set to image("path/to/my-logo.png")
#let logo-horizontal = true // set to true if the logo is squared or horizontal, set to false if not
// Short title on headers
#let short-title = "Rapport de stage"
#let author = "Mateïs FRAMBOURT"
#let date-start = datetime(year: 2026, month: 03, day: 05)
#let date-end = datetime(year: 2022, month: 07, day: 05)
// Set to true for bigger margins and so on (good luck with your report)
#let despair-mode = false
#let first-line-indent-all = auto

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
  image("flexicast_basic.svg"),
  caption: "Organisation des chemins réseaux d'un flot flexicast"
)

Flexicast (#emph("Flexi")ble Multi#emph("cast")) @Flexicast est une extension de QUIC et QUIC-MP utilisant les chemins réseau additionnel de QUIC-MP pour permettre une communication multicast. 




#pagebreak()

#bibliography("bib.yml")
