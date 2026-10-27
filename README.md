# Audit de Performance PostgreSQL (19,6M de Lignes)
### Banc de Benchmark et d'Optimisation sur Données Réelles de Production

[![PostgreSQL](https://img.shields.io/badge/PostgreSQL-16-336791?logo=postgresql&logoColor=white)](https://www.postgresql.org/)
[![Ruby on Rails](https://img.shields.io/badge/Ruby_on_Rails-7.1-CC0000?logo=ruby-on-rails&logoColor=white)](https://rubyonrails.org/)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

---

## 🎯 Contexte & Objectif

Sur une application SaaS B2B exploitant **PostgreSQL 16** (19,6M de réponses, 4,1M de sondages), les tableaux de bord subissaient des timeouts critiques (**> 28 secondes** sur Heroku).

L'hypothèse initiale préconisait une **migration lourde vers ClickHouse (OLAP)** avec un pipeline ETL.  
Cet audit empirique prouve que le problème était purement logiciel : **deux index ciblés et un mot-clé SQL (`DISTINCT`) ont suffi à diviser les temps par 20 sans toucher à l'infrastructure.**

---

## 📊 Résultats Avant / Après Optimisation

Mesures relevées sur l'environnement de test (PostgreSQL 16, 2 vCPUs, 2 Go RAM) exécutant les **vrais services Rails** de l'application :

| Service Applicatif Testé | Avant (Baseline) | Après Optimisation | Gain Mesuré | Statut |
| :--- | :---: | :---: | :---: | :---: |
| **1. Évolution NPS** (`NpsEvolutionDataBuilder`) | 8 963 ms | **1 470 ms** | **-84 %** | 🟢 Résolu |
| **2. Évolution CSAT** (`CsatEvolutionDataBuilder`) | 9 834 ms | **2 005 ms** | **-80 %** | 🟢 Résolu |
| **3. Tableau CSAT** (`CsatTableBuilder`) | 38 095 ms | **1 391 ms** | **-96 %** | 🟢 **Timeout Éliminé** |
| **4. Liste Questions** (`QuestionsBuilder`) | 32 335 ms | **1 628 ms** | **-95 %** | 🟢 **Timeout Éliminé** |

---

## 🔬 Les 2 Goulots Résolus

1. **La Boucle Imbriquée (134 262 itérations) :**
   * *Problème :* Une sous-requête non dédoublonnée forçait PostgreSQL à répéter 134 262 scans d'index (9,7s).
   * *Solution :* Ajout de `DISTINCT` dans la sous-requête $\to$ Bascule immédiate en `Hash Join` en mémoire vive (**293 ms**).
   * *Vérification :* 0 différence constatée sur les 22 826 lignes (intégrité 100 % garantie).

2. **L'Index Incomplet (33 249 blocs de disque lus) :**
   * *Problème :* Seul `restaurant_id` était indexé, forçant le moteur à lire 266 Mo de table brute sur disque pour vérifier `customer_id` (8,9s).
   * *Solution :* Création d'un index composite B-Tree `(restaurant_id, customer_id)` $\to$ Filtrage direct en mémoire vive (**1,4 s**).

---

## 📁 Organisation du Dépôt

```text
├── script-tests-de-performance/
│   └── benchmark_real_services.rb        # Harnais de test Rails instrumenté
├── sql-d-exemple/
│   ├── 01_nested_loop_case_study.sql     # Étude de cas 1 : Boucle imbriquée -> Hash Join
│   └── 02_composite_index_case_study.sql # Étude de cas 2 : Bitmap Heap Scan -> Index Composite
├── resultats-avant-apres-optimisation/
│   ├── 01_baseline_real_services.txt     # Sortie brute initiale (timeouts à 38s)
│   └── 02_optimized_real_services.txt    # Sortie brute validée (tous < 2s)
└── documents-explicatifs/
    ├── philosophie_et_demarche.md        # Note : Démarche empirique vs Refonte ClickHouse
    └── guide_lecture_explain.md          # Aide-mémoire : Lire un EXPLAIN en 30s
```

---

## 🚀 Lancement Rapide

```bash
# Cloner le dépôt
git clone https://github.com/romainchavalle/postgresql-performance-audit-harness.git
cd postgresql-performance-audit-harness

# Exécuter le benchmark
bundle exec ruby script-tests-de-performance/benchmark_real_services.rb
```

---

## 👤 Auteur

* **Romain Chavalle** — Audit de Performance & Scalabilité Base de Données
