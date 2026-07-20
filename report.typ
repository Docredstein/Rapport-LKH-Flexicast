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

#let todo() = [

  #align(
    center,

    text(size: 72pt, stroke: red, fill: orange, "TODO"),
  )




]




#show "flexicast": "Flexicast"

#show "rust": [Rust]

#show "python": [Python]

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

Je tiens à remercier Olivier BONAVENTURE, qui a été mon tuteur pendant ce stage, pour sa bonne humeur, sa sympathie et son accompagnement tout au long du stage. Merci pour toutes ces opportunités de découverte du monde doctoral (les défenses publiques, la journée doctorale, …). Je pense que ça m'a beaucoup éclairé sur mon orientation et je pense qu'une thèse est plus qu'envisageable. Donc merci encore pour ce stage !







Je souhaite d'autre part remercier Louis NAVARE pour son accueil, sa joyeuseté et son dynamisme. Franchement, merci beaucoup, je pense que sans lui ce stage aurait été beaucoup moins fun, de sa compétence technique #text(size: 3pt, [_(Le goat)_]) ou de sa présentation des meilleurs coins de Louvain-la-Neuve. Merci beaucoup, je te souhaite de finir avec succès ta thèse !







Je souhaite aussi Ambroise SIRVEN qui a été mon co-stagiaire sur Flexicast. Ce stage fut super fun et intéressant en grande partie grâce à nos innombrables débats sur tous les sujets imaginables. Merci pour toutes ces bonnes idées qui m'ont permis de me débloquer quand je n'étais pas sûr de la prochaine action à entreprendre.







Je souhaite remercier toute l'équipe pour son accueil chaleureux (notamment la magnifique patate douce de Tom ! :D). Grâce à vous, je pense que j'ai peut-être pu mieux comprendre ce qu'était le rôle de doctorant (même si je suppose qu'il y a des différences en France) entre publication, expérience, présentation… J'espère que nous nous recroiserons à l'avenir !





#pagebreak()




// Executive summary

#heading(level: 1, numbering: none, outlined: false)[Abstract]

La transmission multicast permet de distribuer l'effort de duplication sur le réseau. Cependant, tous les utilisateurs ne peuvent pas nécessairement avoir accès aux arbres multicast. Dans ce cadre, Flexicast, une extension de QUIC, a été développée. Avec cette extension, un serveur peut transmettre efficacement un flux mêlant unicast et multicast. Cependant, la gestion de clé ne supporte que la transmission d'une clé statique. Ce n'est pas suffisant car il n'est alors pas possible de retirer un utilisateur du flux ou d'empêcher un nouvel utilisateur de déchiffrer le contenu précédant son entrée. Il est donc souhaitable d'avoir une clé dynamique changeant à chaque mouvement d'utilisateur. Dans ce sens, ce rapport implémente en Python et en Rust une méthode de gestion de clé sur arbre binaire permettant d'assurer cette dynamicité efficacement. Cette implémentation est ensuite intégrée à Flexicast Quiche, une implémentation en Rust de Flexicast.

#pagebreak()




// Table of contents

#outline(title: [Table des matières], indent: 1em, depth: 2)




// Defining header and page numbering (will pagebreak)

#show: template.apply-header-footer.with(short-title: short-title)





// Introduction

#heading(level: 1)[Introduction]

Les services de diffusion de vidéo en direct fonctionnent sur le principe de la distribution d'un même contenu à plusieurs récepteurs. Cependant, la diffusion est majoritairement réalisée via un routage unicast (1 vers 1) @Livenet, et certains contenus requièrent le chiffrement de ce flux, par exemple dans le cas de services payants. L'unicast implique donc que le serveur chiffre séparément chaque paquet pour chaque récepteur. Cela entraîne un coût calculatoire important : par exemple, le chiffrement d'un flux pour 400 récepteurs sature le serveur, alors qu'un flux UDP pur n'implique aucun coût mesurable (figure 5) @Flexicast.




Dans ce contexte, l'utilisation d'une diffusion en multicast (1 vers $n$) permettrait théoriquement de ne chiffrer qu'une fois chaque paquet. Dans cette optique, Flexicast (#emph("Flexi")ble Multi#emph("cast")) @Flexicast permet d'offrir une communication multicast chiffrée.

Cependant, à l'heure de la rédaction de ce rapport, la spécification Flexicast ne définit pas encore de protocole pour la rotation des clés. Le flux est actuellement chiffré avec une clé statique. Les récepteurs peuvent donc déchiffrer les paquets émis avant qu'ils n'aient rejoint le flux et après l'avoir quitté. Ainsi, Flexicast ne fournit pas de confidentialité persistante (_Perfect Forward Secrecy_) @secDef, ce qui est pourtant nécessaire pour la diffusion de contenus payants (un utilisateur ne devant avoir accès au service que pendant la durée de son abonnement). Il faut donc changer la clé dès qu'un utilisateur rejoint ou quitte l'arbre de diffusion. Une méthode efficace de rotation de clé est donc nécessaire. Ce rapport propose une implémentation de rotation de clé basée sur la Hiérarchie Logique de Clés (_Logical Key Hierarchy_ ou LKH) @cannetiMulticast pour Flexicast.





== Contexte

=== Confidentialité persistante

La confidentialité persistante est définie dans @secDef comme la résistance à la découverte d'une clé privée sans compromettre les paquets précédents.

=== QUIC

QUIC @RFCQuic est un protocole de couche 4 modulaire, léger, fiable et chiffré, reposant sur UDP. Les caractéristiques remarquables de QUIC pour ce rapport sont :

- Un datagramme UDP peut contenir plusieurs paquets QUIC.

- Un paquet QUIC peut contenir plusieurs frames QUIC et est chiffré et authentifié par une clé symétrique.

- Une frame QUIC est l'unité de donnée contenant les données applicatives et les données de contrôle.




=== QUIC Multipath

QUIC Multipath (QUIC-MP) @Multipath est une extension de QUIC ajoutant la possibilité pour une connexion QUIC d'avoir plusieurs chemins réseau. Les caractéristiques notables dans le cadre de ce rapport sont :

- Une connexion QUIC peut avoir plusieurs chemins réseau simultanément.

- Les chemins réseau peuvent être unidirectionnels.

– Les acquittements peuvent être envoyés sur un chemin réseau indépendamment du chemin réseau de réception grâce aux frames PATH_ACK qui spécifient le chemin par lequel a été reçu le paquet.

=== Flexicast

#figure(
  image("Flexicast_basic.svg", height: 30%),

  caption: "Organisation des chemins réseau d'un flot Flexicast",
)




Flexicast (#emph("Flexi")ble Multi#emph("cast")) @Flexicast est une extension de QUIC et QUIC-MP utilisant les chemins réseau additionnels de QUIC-MP pour permettre une communication multicast. Chaque client (utilisant Flexicast) possède deux chemins réseau :

- Un chemin unicast bidirectionnel chiffré par la clé négociée, identique au protocole QUIC standard.

- Un chemin multicast unidirectionnel du serveur vers le client, chiffré avec une clé de session (notée $K_s$) envoyée par le serveur sur le chemin unicast.

Les acquittements sont envoyés uniquement sur le chemin unicast.

Le processus standard pour rejoindre un flot Flexicast se déroule de la manière suivante (détaillé dans @FlexicastClientStateMachine) :

- Le client se connecte en unicast au serveur (il y acquiert la clé de communication unicast).

- Le serveur propose un ou plusieurs flots Flexicast (avec une frame "MC_ANNOUNCE").

- Le client annonce vouloir rejoindre un flot (avec une frame "MC_STATE(join)").

- Le serveur envoie la clé de session par l'unicast (avec une frame "MC_KEY").

- Le client confirme avoir rejoint le flot (avec une frame "MC_STATE").

- Le client peut quitter le flot ou être expulsé par le serveur (par une frame "MC_STATE").





=== Flexicast Quiche

#figure(
  image("schéma_fcquiche_louis.png"),

  caption: [Organisation des tâches Tokio d'un serveur Flexicast Quiche (directement issue de @Flexicast)],
)<FCQUICHE>

Flexicast Quiche @FlexicastGithub est une implémentation de Flexicast (client et serveur) en Rust#box(image("rust.png", height: 0.5em), baseline: 0.25em)@rustLogo se basant sur l'implémentation de QUIC Quiche de Cloudflare et sur la bibliothèque Tokio@Tokio pour assurer l'exécution multitâche. Tokio est centré sur l'utilisation de tâches qui communiquent par passage de messages. Dans Flexicast Quiche, les catégories de tâches sont réparties en :

- "FC_Flow" (Flexicast flow) : gère le flux sur l'arbre multicast et communique uniquement avec le contrôleur racine.

- "Controller" : gère la liaison Unicast-Flexicast. Il est séparé en 2 sous-catégories pour permettre une scalabilité horizontale en

- Un unique contrôleur racine (côté multicast), qui informe les contrôleurs feuilles des paquets QUIC envoyés sur le flux multicast.

- Un ensemble de contrôleurs de feuilles (côté unicast) agrègent les acquittements des chemins unicasts.

- "UC" (Unicast) : un ensemble de contrôleurs, chacun gère une unique connection QUIC unicast avec un client et peut communiquer avec un unique contrôleur feuille.

La synchronisation entre les chemins unicasts et le flot Flexicast est réalisée par un message envoyé périodiquement depuis le "FC_Flow" informant les contrôleurs du dernier numéro de paquet envoyé.

Lorsqu'un client choisit de rejoindre le flot Flexicast, un message annonçant l'arrivée d'un nouveau client est propagé depuis les connexions UC vers les contrôleurs feuille.

#pagebreak()

= État de l'art

Le problème étudié est appelé le chiffrement de diffusion (_Broadcast Encryption_)@BroadcastEncryption. Une source souhaite diffuser un contenu à un ensemble de récepteurs dynamiques. Il est possible que d'autres récepteurs interceptent tous les messages sur le canal, mais ils ne doivent pas être en mesure de déchiffrer le contenu. Pour la suite, le nombre de récepteurs privilégiés (RP) sera noté $n$ et l'ensemble des récepteurs sera noté $R$.

== Solutions "naïves"

=== Simili-unicast

La première solution @BroadcastEncryption consiste à associer une clé par RP et à dupliquer le contenu $n$ fois pour le chiffrer avec chaque clé. Cette solution correspond à celle qui est utilisée en l'absence de multicast. La quantité de données à envoyer est linéaire relativement à $n$ et nécessite $n$ chiffrements. Cela entraîne une consommation processeur suffisante pour saturer le serveur dès $n=400$ dans la baseline pour le test de Flexicast @Flexicast.

=== Rotation unicast

Une première optimisation possible est d'introduire une clé de session. C'est à dire une clé unique pour chiffrer le contenu à diffuser. En cas de changement des RP, une nouvelle clé est générée et est envoyée sur chaque lien unicast des RP. Cette méthode nécessite donc $n$ chiffrements pour la rotation et $1$ chiffrement pour le contenu.

Cette solution n'est pas suffisante pour Flexicast car il est théoriquement possible d'y avoir plusieurs milliers de RP.

=== Solution sans message @BroadcastEncryption

Une solution pour limiter le nombre de messages est de considérer qu'il est uniquement nécessaire d'assurer le chiffrement de diffusion pour un nombre de receveurs ennemis (donc non privilégiés) <=k⋅ C'est ainsi qu'est définie la k-résilience. Une méthode (théoriquement) simple consiste à créer un ensemble de clés et à les distribuer en considérant tous les sous-ensembles de R de cardinal<=k et à donner une clé pour chaque complémentaire de ces ensembles. De cette manière, il est possible de construire une clé de session k-résiliente. Cependant, le coût mémoire de cette solution est exponentiel en k. De plus, il est théoriquement possible pour un flot Flexicast d'avoir une quantité infinie de RP et donc aussi de récepteurs ennemis. Ainsi, la k-résilience n'est pas suffisante.




== Solution à arbres binaires

#figure(
  image("tree_A32.svg"),

  caption: "Arbre binaire, les utilisateurs sont les nombres rouges et les ID de clés les numéros sous les nœuds",
)<Arbre_binaire>

Dans l'optique de réduire le nombre de messages, il est possible d'enregistrer les utilisateurs dans un arbre binaire pour lequel chaque nœud est associé à une clé. De cette manière, il est possible d'envoyer un message en multicast directement à un sous-ensemble des utilisateurs enregistrés et ce pour un coût mémoire relativement limité pour le receveur.





=== Receveurs sans état

La littérature propose des méthodes @TraitorTracing@LSD pour permettre d'assurer le chiffrement de la diffusion sans changer l'état des RP. Ces méthodes fonctionnent sur la création d'arbres binaires et la sélection de sous-arbres recouvrants. Ces méthodes permettent aussi le traçage de traître, qui consiste en l'identification d'un potentiel "traître" qui rediffuserait le contenu. Ces méthodes n'utilisent pas de clé de session mais un ensemble de clés à utiliser comme en simili-unicast.




==== Sous-arbre complet @TraitorTracing

Un arbre binaire de clés est généré et, pour chaque utilisateur révoqué, les nœuds frères du chemin de l'utilisateur jusqu'à la racine sont notés. (par exemple, dans @Arbre_binaire, si l'utilisateur 1 est révoqué, les nœuds [33,17,9,5,3] sont notés). En répétant cette opération pour chaque utilisateur révoqué, une collection de sous-arbres recouvrant les RP est créée. Ensuite le message est chiffré avec une clé de session K qui est chiffrée une fois avec chaque clé associée à une racine des sous-arbres de la collection. Le message final est




$ [id_1,...,id_l,E_(L_(id_1))(K),...E_(L_(id_l))(K),E_K (M)] $

avec $id_i$, les identifiants des clés $L_(id_i)$, E_A(B) la fonction de chiffrement de B par la clé A et M le contenu à diffuser.

\ En notant $r$ le nombre de RP révoqués, la taille du header nécessaire est bornée par $r log(n/r)$ pour $log(n)$ clé stockée par chaque receveur @TraitorTracing.

==== Différence de sous-ensembles @TraitorTracing

Cette méthode est très similaire à la précédente, l'objectif est de trouver une collection d'ensembles minimale recouvrant exactement les RP. Dans cette méthode, les ensembles considérés sont plus flexibles et sont définis comme la différence de sous-arbres. C'est à dire sous la forme S(i,j), le sous-arbre ayant pour racine i mais n'appartient pas au sous-arbre de racine j. Par exemple, pour @Arbre_binaire, $S(4,9)$ contient les receveurs $[1,17,9,25]$.

Il est possible, moyennant une création de clé décrite dans @TraitorTracing de réduire la taille du header à une borne de $2r -1$ au coût d'un stockage de $(log(n))^2/2$ sur chaque receveur.

== Hiérarchie Logique de Clé (LKH) @cannetiMulticast

Cette méthode est toujours basée sur un arbre binaire complet où les RP en sont les feuilles. Cependant, ici l'arbre (et donc les clés) est dynamique, il ne contient strictement que les RP et la clé de session est la clé de session associée. Elle ne nécessite pas d'en-tête particulier. Cependant, les receveurs doivent donc changer de clé à chaque ajout ou retrait d'un RP. Si une clé est perdue, le receveur n'est donc plus capable de déchiffrer correctement toute la suite du contenu. Dans le cas de Flexicast, ce n'est pas un problème car QUIC assure la livraison dans l'ordre de tous les paquets. Le principal avantage de cette méthode est qu'elle est simple à implémenter et théoriquement simple à intégrer à QUIC. En effet, il n'y a qu'une seule clé pour le contenu et sans header supplémentaire, il suffit de changer le secret utilisé dans la suite SSL pour suivre le flux. (En pratique, il y a quelques problèmes de synchronisation, rotation,...)




=== Modification de l'arbre

#figure(
  grid(

    columns: 2,

    figure(
      image("Rapporttree_A05.svg"),

      caption: "Ajout de l'utilisateur 5, les clés mises à jour sont affichées en rouge",
    ),

    figure(
      image("Rapporttree_R01.svg"),

      caption: "Retrait de l'utilisateur 1, les clés mises à jour sont affichées en rouge",
    ),
  ),
) <exemple_lkh>




Lors de l'ajout ou de la révocation d'un receveur, l'arbre est modifié pour stocker ou oublier le receveur concerné, puis le chemin du nœud du receveur jusqu'à la racine est parcouru, en changeant la clé de chaque nœud traversé. Ces clés sont ensuite transmises aux deux enfants en chiffrant la clé avec la clé des nœuds enfants.

Pour l'exemple de la @exemple_lkh, les messages envoyés sont : $ E_K_1(K_9), E_K_8(K_9),E_K_9(K_5),E_K_4(K_5), E_K_5(K_3),E_K_7(K_3) $ Ainsi chaque utilisateur encore dans l'arbre a connaissance des nouvelles clés entre lui et la racine.





Les mises à jour nécessitent donc $2log(n)$ messages, mais les messages portant du contenu sont indépendants du nombre d'utilisateurs révoqués.

=== Optimisations possibles

==== Arbre à fonction à sens unique

#figure(
  image("OFT.gif", height: 10em),

  caption: [Exemple d'arbre à fonction à sens unique issu de @OFT_LKHP],
) <OFT>

Il est possible de réduire le nombre de messages pour les changements en dérivant une partie des clés directement sur le receveur. Pour cela, chaque nœud stocke 2 éléments : un secret et la clé. La clé est issue, par une fonction de dérivation, du secret. Le secret est soit défini si le nœud est feuille, soit calculé grâce aux 2 nœuds fils.

Le secret d'un nœud non-feuille est calculé en utilisant le ou exclusif des secrets "obscurcis" (hashés) des 2 fils.

Il suffit dès lors d'envoyer uniquement $log(n)$ clés lors d'un changement (le chemin direct depuis le changement vers la racine). Le stockage nécessaire pour chaque receveur est donc de $2log(n)$.




Cette méthode n'est, cependant, pas convenable car elle est vulnérable à une attaque par collusion @Attack_OFT. En effet, si 2 receveurs coopèrent, ils peuvent avoir accès à la clé de session d'une période pendant laquelle aucun des deux n'est dans l'arbre. Par exemple sur la @OFT, en 3 temps :

- Un utilisateur rejoint l'arbre et est placé sous $x_2$, il connait donc $f(x_3)$.

- Cet utilisateur part et $x_2$ est remplacé par $x_2'$, la clé de session est donc $g(f(x_2') xor f(x_3))$

- Un utilisateur rejoint l'arbre et est placé sous $x_3$, il connait donc $f(x_2')$

Ainsi si ces 2 utilisateurs coopèrent, ils connaissent $f(x_2') xor f(x_3)$ donc la clé de session intermédiaire.

Il existe des propositions résistantes à la collusion, mais elles paraissaient trop complexes à implémenter en première approche.

==== LKH+

L'utilisation d'un arbre binaire crée des cas où le nombre de clés à diffuser est pire que l'unicast. Notamment lorsqu'il y a peu d'utilisateurs. D'autre part, un attaquant désireux de consommer excessivement du temps de calcul pourrait continuellement rejoindre et quitter le flux, engendrant à chaque mouvement une nouvelle série de messages de mise à jour, ce qui pourrait, potentiellement, occuper la totalité du canal, bloquant ainsi la diffusion du contenu. Pour cela il est possible d'ajouter les RP par groupe @Attack_OFT. Pour cela, il suffit d'ajouter virtuellement des RP directement sous la racine en ne leur transmettant que la clé de session jusqu'à atteindre une quantité minimale d'utilisateurs, puis de les ajouter dans l'arbre.

=== Considération de sécurité

Le chiffrement d'une nouvelle clé avec une ancienne clé crée une chaine qui peut être représentée par un graphe. Un protocole de chiffrement de diffusion où ces chaînes ont une longueur maximale de 1 admet une équivalence entre la résistance à la corruption d'un unique utilisateur et la résistance à la collusion@CorruptionEquivalence.  Pour les protocoles précédents, les protocoles sans état sont donc résistants car ils ne chiffrent la clé de session qu'avec les clés des sous-ensembles. D'autre part, pour LKH, il n'y a pas l'équivalence car, selon l'implémentation, la nouvelle clé de session peut être chiffrée avec l'ancienne, et ce plus d'une fois. Pour résoudre ce problème, il suffit de dériver 2 clés, une clé de chiffrement de contenu et une clé de chiffrement de clé @CorruptionEquivalence.



#pagebreak()
= Implémentations

== Python

Dans un premier temps, n'ayant jamais écrit de Rust, un module LKH Python a été écrit. L'idée était de commencer à débuguer sur un langage qui m'était connu et qui est rapide à écrire. L'objectif de ce module n'est pas d'implémenter Flexicast en Python mais strictement la distribution de clé.




=== Interface

Pour modéliser les deux interfaces disponibles dans Flexicast (multicast et unicast), une approche fonctionnelle a été utilisée. Pour cela, un utilisateur est représenté par la classe : \

#figure(
  ```python
  class User:
    def __init__(self, userID: str, send: Callable[[bytes], None]) -> None:
      self.userID = userID
      self.send = send ```,

  caption: "Interface pour un récepteur",
)

- `send` représente ici une fonction qui permet d'envoyer des bytes en unicast vers cet utilisateur.
- `userID` est ici une chaîne de caractères, mais il suffit d'une méthode hashable permettant d'identifier uniquement chaque utilisateur.



L'arbre est défini de la manière suivante :

#figure(
  ```python
  class LKH:
    def __init__(self, sendGroup: Callable[[bytes], None], debug=False) -> None:
      self.depth: dict[int, set[int]] = {}  # Association Couche  -> keyId
      self.nodes: dict[int, Node] = {}      # Association Keyid   -> Node
      self.users: dict[str, Node] = {}      # Association Userid  -> Node
      ...```,

  caption: "Interface pour LKH",
)




Ainsi le canal multicast appartient à l'arbre et est modélisé par une fonction permettant de transmettre des bytes à tous les récepteurs. La structure de LKH+ peut donc être implémentée relativement facilement en adjoignant un ensemble d'utilisateurs hors de l'arbre à LKH:

#figure(
  ```python

  class LKHPlus(LKH) :

      def init(self, sendGroup: Callable[[bytes], None], debug=False, allowableUnorderedUserCount:int=256) -> None:
          super().__init__(sendGroup, debug)
          self.unorderedUsers:set[User] = set()
          self.allowableUnorderedUserCount = allowableUnorderedUserCount

  ```,

  caption: "Extension de LKH en LKH+",
)





L'arbre est ensuite défini par une classe récursive :

#figure(
  [```python
  class Node:
      def __init__(
          self,
          id: int,
          left: Node | None = None,
          right: Node | None = None,
          parent: Node | None = None,
          key: bytes = b"",
          keyid: int = 0,
          user: User | None = None,
          depth: int = 0,
      ) -> None:```],

  caption: "Définition d'un nœud de l'arbre",
)





Et l'ajout/retrait d'utilisateurs est réalisé simplement de la manière suivante :

```python
def addUser(self, user: User)
def removeUser(self, user: User) ```




=== Récepteur

Un point notable pour LKH est la simplicité de mise à jour pour les clients. En effet, il n'est pas nécessaire pour le récepteur de connaitre la position des clés dans l'arbre. De cette manière, il suffit d'un dictionnaire indexant les identifiants de clés connues. Cependant, il est nécessaire d'indiquer alors explicitement si la nouvelle clé correspond à la clé de la racine. D'autre part, le paquet de rotation de clé n'a besoin d'être chiffré que sur le chemin multicast. Pour cela, le paquet de rotation en clair est conçu pour être "emballé" dans un paquet indiquant la clé utilisée.

Le paquet en clair a donc été défini de la manière suivante :

```python

class KeyUpdatePacket(Packet):
    def init(
        self, newKey: bytes, newKeyid: int, isSessionKey: bool, deleteNewKey: bool):
```

```py
class WrappedKeyUpdatePacket(Packet):
  def init(self, aad:bytes,nonce:bytes,ciphertext:bytes):
```

`aad` pour additional authentified data contient l'identifiant de la clé utilisée pour chiffrer le paquet. Cette valeur est en clair mais est authentifiée au déchiffrement, ce qui empêche toute modification de cette valeur par un attaquant sur le chemin.



#pagebreak()
=== Ajout d'un utilisateur

La procédure d'ajout d'un utilisateur doit limiter au maximum la profondeur maximale de l'arbre. En effet, plus l'arbre est profond, plus le récepteur doit stocker de clés. Pour réaliser cette opération, il suffit de stocker un dictionnaire associant une profondeur à l'ensemble des feuilles à cette profondeur. Il suffit ensuite d'itérer sur ses clés pour trouver la liste non vide de profondeur minimale et de retirer un nœud de cette liste. Ce nœud est ensuite séparé en deux pour finalement changer les clés en parcourant le chemin depuis le nouveau récepteur jusqu'à la racine. Ici, le dictionnaire des profondeurs peut explicitement être mis à jour car on ne peut séparer que des feuilles.

En notant `kid{n}` les identifiants de clé et `k{n}` les clés , l'ajout d'un utilisateur suit donc ces 3 étapes :




#figure(
  grid(

    columns: 2,

    gutter: 1mm,

    figure(
      image("AddClient/selection_split.svg"),

      caption: "Sélection du nœud à séparer",

      numbering: none,
    ),

    figure(
      image("AddClient/insertion_d.svg"),

      caption: "Insertion du nouveau récepteur",

      numbering: none,
    ),

    grid.cell(colspan: 2, figure(
      image("AddClient/rotation_clé.svg", height: 30%),

      caption: "Rotation des clés",

      numbering: none,
    )),
  ),

  caption: [Ajout d'un récepteur],
)





=== Révocation d'un utilisateur

La révocation impose des problèmes tout à fait différents. Il n'est pas possible de choisir une topologie alternative optimale car le nœud à supprimer est fixé. Cependant, un problème notable est que le nœud frère du nœud à supprimer (a fortiori celui qui devra être "remonté") peut ne pas être une feuille mais être un sous-arbre. Il faut donc réparer les différents dictionnaires. D'autre part, la rotation de clé n'est pas nécessaire pour les 2 nœuds supprimés, mais il est nécessaire d'envoyer une mise à jour pour indiquer que ces clés sont inutiles et peuvent être supprimées. La rotation ne doit donc être faite que pour le nœud grand-père de la feuille supprimée.




#figure(
  grid(

    columns: 3,

    gutter: 1mm,

    figure(
      image("RemoveClient/initial.svg"),

      caption: "Nœuds à supprimer",

      numbering: none,
    ),

    figure(
      image("RemoveClient/DepthUpdate.svg"),

      caption: "Correction récursive de la profondeur",

      numbering: none,
    ),

    figure(
      image("RemoveClient/keyupdate.svg"),

      caption: "Rotation des clés",

      numbering: none,
    ),
  ),

  caption: [Procédure pour la révocation d'un utilisateur],
)






=== Comparaisons

Pour évaluer l'intérêt pratique de ces organisations de clés en fonction du nombre d'utilisateurs, une simulation est réalisée : $n$ utilisateurs sont créés et commencent hors de l'arbre, à chaque étape un utilisateur est tiré équiprobablement et son état est changé (s'il était dans l'arbre il en sort et inversement) et ce pour $15n$ étapes. Il n'y a donc que des messages de contrôle.

#figure(
  grid(

    columns: 2,

    image("ComparaisonUNIFClose.svg"), image("ComparaisonUNIFLarge.svg"),
  ),

  caption: "Comparaison des algorithmes avec une répartition équiprobable des actions",
)

Ce résultat montre qu'il y a effectivement une réduction du nombre de chiffrement nécessaire relativement à une rotation de clé sans multicast, de l'ordre de 94%. Cependant, LKH+ semble augmenter le nombre de chiffrements nécessaires (au minimum de 2% et au maximum de 216%). Pour autant cette simulation est réalisée dans le cas où chaque utilisateur a la même probabilité, or l'avantage théorique est quand un utilisateur reste hors de l'arbre puis le quitte. Un scénario plus avantageux pour LKH+ est testé ; dans celui-ci, un utilisateur a une probabilité de 0.5 de réaliser une action et les autres utilisateurs sont répartis équiprobablement.




#figure(
  grid(

    columns: 2,

    image("ComparaisonAnnoyingClose.svg"), image("ComparaisonAnnoyingLarge.svg"),
  ),

  caption: "Comparaison des algorithmes avec une répartition d'action favorisant fortement un utilisateur",
)

Dans le cas où il y a un utilisateur réalisant des actions nettement plus fréquemment, LKH+ peut réduire le nombre de chiffrement de 33% (ici quand le nombre maximal de RP hors arbres est de 8).




== rust

Un module Rust a ensuite été développé pour pouvoir bénéficier des assurances de sécurité garanties par Rust et pour l'intégrer facilement dans flexicast Quiche. Cependant, Rust est un langage très différent de Python, notamment :

- Rust n'est pas complètement orienté objet, il n'y a pas d'héritage de classe mais des structures implémentant des traits composés d'un ensemble de fonctions et d'autres traits. Il n'y a donc pas d'héritage de membre d'une structure.

- Rust impose un système de possession, chaque donnée appartient à une unique entité. Il est possible de prêter la donnée ou une référence. Cependant, ce prêt est limité, il peut y avoir un nombre arbitraire de références immuables (en lecture seule) mais il est alors impossible de la modifier, même par le propriétaire initial. D'autre part, il ne peut y avoir qu'une unique référence mutable, ce qui peut être problématique.

=== Interfaces

En se basant sur le module en python, un utilisateur est modélisé d'une manière analogue,

#figure(
  ```rs

  pub struct User {

      pub user_id: Vec<u8>,

      pub send: Box<dyn Fn(KeyUpdatePacket) + Send + Sync>,

  }

  ```,
)

Chaque utilisateur doit donc avoir un identifiant unique et avoir une fonction qui envoie des `KeyUpdatePacket` tout en pouvant être transmis entre différents fils d'exécution.




Il faut ensuite définir l'interface pour tout système de gestion clé. Il doit être possible d'ajouter des utilisateurs, de les révoquer et de récupérer la clé de session actuelle.

#figure(
  ```rs
  pub trait LogicalTree {
  ///Add a user designated by `user_id` and a fonction `send` that send a vec8 to the user.
    fn add_user(&mut self,
                user_id: Vec<u8>,
                send: Box<dyn Fn(KeyUpdatePacket) + Send + Sync>)->();
    ///Remove a user designated by `user_id`
    fn remove_user(&mut self, user_id: Vec<u8>) -> ();
    ///Return a tuple `(key_id, key)` if possible
    fn get_session_key(&self) -> Option<(u64, &[u8])>;}  ```,
)
Finalement, LKH est interfacé de 2 manières :

- Pour l'interface avec le flux multicast, celle-ci reprend l'architecture du module Python en utilisant une fonction qui prend un `WrappedKeyUpdatePacket` et l'envoie sur le flux multicast :

#figure(
  ```rs
  pub struct Lkh {
      tree: Tree,
      key_size: usize,
      send_group: Arc<Box<dyn Fn(WrappedKeyUpdatePacket) + Send + Sync>>,}
  ```,
)

- Une interface pour la cryptographie est aussi nécessaire pour éviter d'augmenter le nombre de dépendances et de redondances dans Flexicast Quiche. Cette interface doit permettre de générer des clés, de chiffrer et de déchiffrer des messages. Pour cela, un fichier `lkhcrypto.rs` à part est créé et où trois fonctions sont déclarées :
#figure(
  ```rust
  pub fn generate_key(key_size :usize) -> Vec<u8>
  ```,
)

#figure(
  ```rust
  pub fn lkh_encrypt(
        packet: WrappedKeyUpdatePacket,
        algo: Algorithm,
        counter:u64)
        -> Result<KeylessWrappedKeyUpdatePacket,Error>```,
)

#figure(
  ```rust
  pub fn lkh_decrypt(
      packet: KeylessWrappedKeyUpdatePacket,
      key: Vec<u8>,
      algo: Algorithm,) -> Option<KeyUpdatePacket>
  ```,
)




=== Structures adoptées

==== Arbre

Pour être plus facile à adapter au système de possession de Rust, l'arbre est un array plutôt qu'une structure récursive. Cependant, un point notable est que les nœuds ont un identifiant défini de manière récursive. La racine a un identifiant de 1 et pour un nœud $n$, son nœud à gauche a un identifiant de $2n$ et celui de droite de $2n+1$, les nœuds sont ensuite stockés dans l'array en prenant leur identifiant-1. Pour représenter un nœud vide, le type stocké dans l'array est un ```rs Option<Node>``` qui peut valoir soit ```rs Some(Node)``` ou ```rs None```.

#figure(
  image("structureArbre.svg"),

  caption: [Structure utilisée pour stocker l'arbre],
)

Cette structure a l'avantage de ne pas avoir de chaîne de possession interne, mais la modification de l'arbre est moins efficace car les relations de parenté doivent être maintenues "manuellement" ce qui nécessite d'itérer sur tous les enfants pour les déplacer au bon index.

==== Paquets

Dans le module Python, les paquets n'étaient pas définis proprement car ils n'avaient pas pour objectif d'être intégrés, moins encore d'être standardisés. Ce n'est pas le cas pour le module Rust, donc les paquets de mises à jour sont définis en 3 types :

- ```rs
  struct KeyUpdatePacket {
    /// The updated key vector
    pub new_key: Vec<u8>,
    /// The identifier designating the updated key
    pub new_key_id: u64,
    /// Should the updated key be the considered as the new session key
    pub is_session_key: bool,
    /// Should this key be removed from the list of keys of the receiver
    pub delete_new_key: bool,}```Ce paquet est la base pour tous les paquets utilisés dans LKH, il ne peut être envoyé en tant que tel que sur le chemin unicast car il n'est pas chiffré.

- ```rs struct WrappedKeyUpdatePacket``` qui contiennent un KeyUpdatePacket en clair, l'identifiant de clé et la clé pour le chiffrement du paquet. Ce paquet ne doit donc jamais être envoyé sur le réseau.

- ```rs struct KeylessWrappedKeyUpdatePacket``` qui est le WrappedKeyUpdatePacket après le chiffrement, donc qui contient un KeyUpdatePacket chiffré et uniquement l'identifiant de clé pour ce chiffrement. Il est utilisé sur le chemin multicast.

Ces paquets sont ceux utilisés dans les fonctions interfaces. La sérialisation de ces paquets est aussi gérée par le module.

==== Tests

Un avantage de Rust est son support intégré pour les tests. Il est possible de définir des modules de tests directement dans les fichiers sources liés. Dans cette version du module en Rust, des tests ont été mis en place au niveau de l'arbre sans LKH (ajout/retrait de nœud, remonter/descendre un sous-arbre) et de LKH (ajout/retrait d'1/4/16/32 utilisateurs, tests d'action aléatoires, vérification des clés de chaque utilisateur relativement à l'arbre). Au total, 27 tests ont été implémentés pour une couverture de 96% des lignes de code. En pratique, cela a permis d'être plus sûr des modifications apportées à l'implémentation de LKH, ce qui posait particulièrement problème sur le module Python.



#pagebreak()
= Intégration
Pour intégrer le module dans FCQuiche (Flexicast Quiche) il faut modifier la partie contrôle (donc la partie avec les contrôleurs présent dans @FCQUICHE) et la partie connexion (donc la partie gérant directement la connexion QUIC). Pour être plus compréhensible, l'explication va globalement suivre les messages envoyés.
== Contrôleur
=== Création de l'arbre
Avant l'arrivée de tout récepteur, le contrôleur initialise un vecteur d'arbre binaire, un pour chaque flot Flexicast. Ceux-ci sont définis uniquement
par le trait `LogicalTree` défini précédemment ```rs lkh_tree: Vec<Box<dyn LogicalTree>>```  ce qui permet de facilement changer de structure utilisée.
Pour chaque flot, il est nécessaire de créer l'arbre avec une fonction permettant de communiquer avec le flux multicast. Cette fonction est créée en ajoutant un message entre le contrôleur racine et le flot flexicast
```rs KeyUpdateNeededOnMC(WrappedKeyUpdatePacket),``` qui réutilise la définition des paquets précédentes.
Ces messages sont ensuite envoyés dans la file d'attente de messages du contrôleur multicast avec #figure(```rs
let captured = tx.clone();
Arc::new(Box::new(move |packet| {
      match captured.try_send(MsgFcSource::KeyUpdateNeededOnMC(packet)) {
          Ok(_) => (),
          Err(_) => println!("[LKH] Couldn't push a group key update to the channel")
                }
      }))```,caption: [Interface vers le flux multicast])
En traitant ce message, le contrôleur multicast ajoute ces paquets à la file des clés à envoyer de sa connexion QUIC.

D'autre part, les fonctions cryptographiques sont implémentées en réutilisant les fonctions utilisées pour chiffrer les paquets QUIC, cependant, elles nécessitents d'utiliser un compteur pour éviter les attaques par reémission. Pour cela, le contrôleur multicast maintient un compteur pour chaque ID de clé qu'il incrémente à chaque message ajouté dans la file.
Pour des raisons de synchronisation expliquée plus en détail dans le @Connexion, le contrôleur multicast compte aussi le nombre total de clés envoyées sur le flux multicast.

=== Entrée dans l'arbre
Dans FCQuiche, quand un récepteur rejoint un flux Flexicast, le contrôleur feuille reçoit une message ```rs Join``` contenant l'ID unique du client, l'ID du flot et optionnelement le dernier paquet reçu sur le flot s'il l'avait déjà rejoint.
Ce message a été étendu pour que le contrôleur propage ce message jusqu'au contrôleur racine.
Quand le contrôleur racine recoit ce message il ajoute le client en créant la 2ème partie de l'interface :
#figure(
  ```rs
  tree.add_user(
                      recv_id.to_be_bytes().to_vec(),
                      Box::new(move |packet| {
                          for leaf in leaf_controllers.iter() {
                              match leaf.try_send(MsgFcCtl::LKHChangeKeyUnicast((
                                  recv_id,
                                  FCKeyUpdate::KeyUpdate(packet.clone()),
                              ))) {
                                  Err(_) => {
                                      println!("[LKH] root couldn't send message")
                                  },
                                  Ok(_) => (),
                              }
                          }
                      }),
                  );
  ```,
  caption: [Interface avec le flux unicast],
  
)
Pour envoyer un message en unicast, le contrôleur racine envoit donc un message contenant le changement de clé à chaque contrôleurs feuille. Cette implémentation n'est pas vouée à rester car elle est inefficace dès lors qu'il y a au moins 2 contrôleurs feuilles.
Quand un contrôleur feuille reçoit ce message, s'il connait le receiver_id il lui transfère le message et la clé est ajouté dans une file de la connection unicast.

Avec ces deux interfaces préparées, l'arbre envoit des messages vers le flot multicast et les contrôleurs unicast pour actualiser les récepteurs.
Une fois tous les messages de clés envoyés, un message est envoyé au contrôleur multicast lui indiquant la nouvelle clé de session, le numéro de paquet minimal pour le changement de clé et combien de clés doivent être envoyées avant d'appliquer la nouvelle clé.
Le contrôleur multicast transfère cette notification à la connection QUIC en l'ajoutant dans une file de future changeemnt de session.

=== Problèmes non résolus
L'implémentation de LKH n'est pas encore complète du côté des contrôleurs. En effet, la synchronisation des acquittements n'est pas correcte car le premier numéro de paquet pour lequel le contrôleur racine s'attend à recevoir un acquittements est incorrect. Dans l'implémentation FCQuiche, l'ajout des clients se faisaient avant de transmettre des paquets sur le flux multicast ce qui n'est donc pas le cas avec LKH. Le premier paquet attendu était donc le premier paquet envoyé après avoir le message `Join` ce qui ne prend donc pas en compte les clés envoyées sur le multicast (Le nouveau récepteur ne doit recevoir des clés qu'en unicast uniquement). Pendant cet envoi, le récepteur n'écoute pas le flux multicast et ne l'acquitte donc pas ce qui semble saturer la connexion car les paquets ne sont jamais retransmis.

Le révocation n'a pas encore été proprement implémentée car cette le départ d'utilisateur n'était pas encore  développé dans l'implémentation FCQuiche avant la fin du stage.
Cependant, les interfaces sont déjà configurées donc l'ajout ne devrait théoriquement pas ajouter de complexité particulière.
== Connexion <Connexion>

#todo()


#pagebreak()
#bibliography("bib.yml")
#pagebreak()
= Annexe
#figure(
  image("ClientSideStateMachine.svg",height: 80%),
  caption: "Machine à état du client Flexicast",
)<FlexicastClientStateMachine>












