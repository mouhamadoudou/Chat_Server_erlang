# Projet de Gestion de Communication Utilisateur

Ce projet a été réalisé dans le cadre de ma formation chez Miryad Connect. L'objectif principal est de concevoir un serveur de communication utilisant le protocole TCP pour gérer les échanges entre les utilisateurs.

## Fonctionnalités principales

- Gestion de la communication entre utilisateurs via un serveur TCP.
- Acceptation des connexions TCP par le serveur (peut être réalisée à l'aide de Telnet par exemple).
- Chaque session permet l'envoi de lignes de texte terminées par la touche "Entrée" vers les autres sessions.
- Utilisation de noms conviviaux pour chaque session afin de connaître l'auteur de chaque message (les noms dupliqués ne sont pas autorisés).
- Envoi de tous les échanges précédents à une nouvelle session lors de sa connexion.
- Notification des autres utilisateurs lorsqu'un utilisateur se connecte ou se déconnecte.
- Gestion des déconnexions : en cas de déconnexion d'une session, envoi du message "disconnection of one of your chat partners" à toutes les autres sessions.

## Les Commandes disponibles (attention a la synthax)
  - send user_name : your message
  - send_all : your message
  - disonnect
  
## Exemple d'utilisation

- Démarrer le serveur Erlang sur le port 4000.
- Ouvrir deux sessions Telnet : "telnet localhost 4000"

## Sujet du Projet

Voici le sujet complet du projet :

    two telnet started: "telnet localhost 4000"

    when you type “hello world !” in one telnet, "hello world !" is sent to the other telnet

    a third telnet connect any sentence entered on this new one will be echoed to the other telnet

    when a telnet is stopped the sentence “disconnection of one of your chat partner” should be sent to all other telnet

    to add: each session is using a friendly name to know who type what (of course duplicate name are not permitted)

    to add: when a telnet connect, all previous exchanges are sent to it
