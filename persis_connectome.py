'''
Input: Given a weighted adjacency matrix
Output: Pairwise wassertein distance of graphs for 
'''
# pip install POT
import os
import math
import gudhi
# import persim
import numpy as np
import pandas as pd
import gudhi.wasserstein as ws
import matplotlib.pyplot as plt

datasets = ["control", "glioma", "meningioma"]
classes = ['control','glioma','meningioma']

dir = '/Users/kaveri/Documents/Connectome-FMRI-Persistence-Colab/Data'
out_dir = '/Users/kaveri/Documents/Connectome-FMRI-Persistence-Colab/NewPerisDgms'

q = 1 # internal_p (float) – Ground metric on the (upper-half) plane (i.e. norm L^p in R^2). default value is np.inf

subjlist=[]
h0,h1=[],[]
Betti = {}
for subclass in classes:
    os.makedirs(os.path.join(out_dir,subclass),exist_ok=True)
    Betti[subclass] = {}
    for subj in os.listdir(os.path.join(dir,subclass)):
        Betti[subclass][subj] = {}
        conn=pd.read_csv(os.path.join(dir,subclass,subj),header=None).values        
        try:
            edges=[]
		    # sample edges: [[[0, 2], [0.412986]], [[0, 4], [0.840573]], [[0, 9], [2.897847]]]
            num_vertices = conn.shape[0]
            # print(num_vertices)
            weight_list = [[] for i in range(num_vertices)]
            max_weight = -100000
            one_shot_max = np.max(conn)
            for row_conn in range(num_vertices):
                for col_conn in range(num_vertices):
                    if not conn[row_conn][col_conn]==0: #remove diagonal and no edges
                        edges.append([[int(row_conn),int(col_conn)],[float(conn[row_conn][col_conn])]])
                        if(float(conn[row_conn][col_conn]) > max_weight):
                            max_weight = float(conn[row_conn][col_conn])
                        weight_list[row_conn].append(float(conn[row_conn][col_conn])) # append the edge weight 
                        weight_list[col_conn].append(float(conn[row_conn][col_conn]))
            # print(weight_list)
            simplexTree = gudhi.SimplexTree()
            for v in range(len(weight_list)):
                weight = min(weight_list[v])
                # print(v,weight)# Most of the nodes get a 0 value
                simplexTree.insert([v], filtration=weight)
            for edge in edges:
                simplexTree.insert(edge[0], filtration = edge[1][0])
            s=simplexTree.persistence()
            d1_persistence_diagram_dim0 = simplexTree.persistence_intervals_in_dimension(0)
            # print(d1_persistence_diagram_dim0) # all 0 and inf
            simplexTree.extend_filtration()
            dgms=simplexTree.extended_persistence()
            d1_persistence_diagram_dim1=[]
            for i in range(len(dgms[3])):
                if(dgms[3][i][0]!=1):
                    print('efh')
                dgm = list(dgms[3][i][1])
                dgm.reverse()
                d1_persistence_diagram_dim1.append(dgm)
            Betti[subclass][subj]['H0']=d1_persistence_diagram_dim0
            Betti[subclass][subj]['H1']=d1_persistence_diagram_dim1
            subjlist.append(f'{subj[:-12]}_{subclass}')
            h0.append(d1_persistence_diagram_dim0)
            h1.append(d1_persistence_diagram_dim1)
            # print(np.array(d1_persistence_diagram_dim0).shape)
            # print(np.array(d1_persistence_diagram_dim1).shape)
            pd.DataFrame(d1_persistence_diagram_dim0,columns=['birth','death']).to_csv(f'{out_dir}/{subclass}/{subj[:-12]}_dgm0.csv')
            pd.DataFrame(d1_persistence_diagram_dim1,columns=['birth','death']).to_csv(f'{out_dir}/{subclass}/{subj[:-12]}_dgm1.csv')
        except:
            print("Something went wrong !")

for h in [h1]:
    distanceMatrix = np.zeros((len(h),len(h)), dtype = float)
    for i in range(len(subjlist)):
        for j in range(i, len(subjlist)):
            distance = ws.wasserstein_distance(np.array(h[i]),np.array(h[j]),internal_p=q)
            # distance = persim.wasserstein(np.array(h[i]),np.array(h[j]),matching=False)
            distanceMatrix[i][j]=distance
            distanceMatrix[j][i]=distance
    pd.DataFrame(distanceMatrix,columns=[i for i in range(distanceMatrix.shape[0])]).to_csv(f'{out_dir}/{subclass}/wass_h1.csv')
    plt.figure(figsize=(10,10))
    plt.xticks(range(0,36),subjlist,rotation=90)
    plt.yticks(range(0,36),subjlist)
    plt.imshow(distanceMatrix)
    plt.colorbar()
    plt.savefig('latest.png',dpi=400)
    plt.close()
    # plt.show()