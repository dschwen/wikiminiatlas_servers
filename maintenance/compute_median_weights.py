
for z in range(9):
    
    query = 'select count(*) from wma_connect_commons c, wma_label_commons l, wma_tile t WHERE l.id=c.label_id AND c.tile_id=t.id AND z=%(s)'
    tcr.execute(query, z)

