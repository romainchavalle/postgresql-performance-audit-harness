# Aide-Mémoire : Lire un EXPLAIN ANALYZE en 30 Secondes

---

## 1. La Règle d'Or des 3 Métriques

Pour trouver un goulot d'étranglement dans un plan PostgreSQL, regarder uniquement :

$$\text{Temps Réel d'un Nœud} = (\text{actual time fin} - \text{actual time début}) \times \mathbf{loops}$$

1. **`loops` :** Si `loops > 1 000`, le nœud est une boucle qui multiplie le temps.
2. **`Buffers: read=N` :** Nombre de blocs de 8 Ko lus sur le disque. Si $N > 10\,000$, la requête est bridée par les entrées/sorties disque (I/O).
3. **`Rows Removed by Filter` :** Lignes scannées puis jetées faute d'index adapté.

---

## 2. Les 2 Goulots Résolus lors de l'Audit

```mermaid
flowchart LR
    subgraph Cas1["Cas 1 : Nested Loop (134k boucles)"]
        A1["loops=134262<br/>0,06ms x 134 262 = 9,7s"] --> B1["Cause : WHERE IN (...) sans DISTINCT"]
        B1 --> C1["Solution : SELECT DISTINCT<br/>Bascule en Hash Join -> 293 ms (-97%)"]
    end

    subgraph Cas2["Cas 2 : Bitmap Heap Scan (I/O Disque)"]
        A2["Buffers: read=33336<br/>266 Mo de table lus sur disque = 8,9s"] --> B2["Cause : Index sur restaurant_id seul<br/>(customer_id absent de l'index)"]
        B2 --> C2["Solution : Index composite (restaurant_id, customer_id)<br/>Scan 100% en RAM -> 1,4s (-84%)"]
    end
```

---

## 3. Synthèse des Nœuds Clés

| Nœud dans l'EXPLAIN | Diagnostic | Action Corrective |
| :--- | :--- | :--- |
| **`Seq Scan`** | Scan complet de la table sans index | Créer un index sur la colonne filtrée |
| **`Bitmap Heap Scan`** | L'index ne contient pas toutes les colonnes | Créer un index composite couvrant |
| **`Nested Loop` (loops élevé)** | Boucle répétée pour chaque ligne retournée | Ajouter un `DISTINCT` ou réécrire en `JOIN` pour forcer un `Hash Join` |
| **`Index Only Scan`** | **Idéal :** La donnée est 100% dans l'index en RAM | Aucune action, performance maximale |
