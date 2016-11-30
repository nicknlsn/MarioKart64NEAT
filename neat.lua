--===========================================================================--
---------------------------NEAT algorithm for MK64-----------------------------
--===========================================================================--
--                                                                           --
-- Author: Nick Nelson                                                       --
-- November, 2016                                                            --
-- You may freely use this code, but please give credit to the original      --
--   author.                                                                 --
--                                                                           --
-- Setup: create a save state at the beginning of a level. Call it
--   LR150.state and save it in the lua folder. Note: So far I have only
--   tested this on Luigi Raceway with 150cc.
--===========================================================================--

--[[
Known bugs:
- replay best, then reload, in_cell is now nil. update: this only happens
  sometimes, just do it again

Possible bugs:
- in at least one case a single species took over the entire population, which
  could mean i have something wrong in the code that is supposed to prevent
  this...

Haven't tested:
- load a backup file instead of the saved file
- spawning code could use more testing

Areas for improvement:
- adjust mutation code to better suit the problem

Some unknown object types:
- 43 hot air balloon in luigi raceway?
- 42 blue shell I think
- 21 dead banana?
- 22 dead banana?
- 14
]]

function p(line)
	console.write(line)
end

function pn(line)
	console.writeline(line)
end

function initialize_things()
	console.clear()

	-- pn(game)
	pn('MK64 NEAT')

	state_file = "BB150.state"

	-- TODO add bumpers?
	button_input_names = {
	-- "Start",
	"P1 B",
	"P1 A",
	"P1 Z",
	"P1 A Down",
	"P1 A Left",
	"P1 A Right",
	"P1 A Up",
	"P1 L",
	"P1 R" }

	button_actual_names = {
	-- "Start",
	"B",
	"A",
	"Z",
	"Down",
	"Left",
	"Right",
	"Up",
	"L",
	"R" }
	num_buttons = #button_actual_names

	course = {}

	-- collision address
	course.col_addresses = {
	0x1D65A0,  -- Mario Raceway
	0x1D4280,  -- Choco Mountain
	"",
	0x1D8380,  -- Banshee Boardwalk
	0x1E5170,  -- Yoshi Valley
	0x1D4650,  -- Frappe Snowland
	0x1E6380,  -- Koopa Troopa Beach
	0x1DAF50,  -- Royal Raceway
	0x1DD1C0,  -- Luigi Raceway
	0x1E1500,  -- Moo Moo Farm
	0x1F0AC0,  -- Toad's Turnpike
	0x1F0120,  -- Kalamari Desert
	0x1D6A70,  -- Sherbet Land
	0x1E3080,  -- Rainbow Road
	0x1D9AE0,  -- Wario Stadium
	"",
	"",
	"",
	0x1E1300,
	""}  --

	-- the collision attribute for each track
	course.track_attribute = {
	"",  -- Mario Raceway
	"",  -- Choco Mountain
	"",
	6,
	2,  -- Yoshi Valley
	5,  -- Frappe Snowland
	3,  -- Koopa Troopa Beach
	1,  -- Royal Raceway
	1,  -- Luigi Raceway
	2,  -- Moo Moo Farm
	1,  -- Toad's Turnpike
	2,  -- Kalamari Desert
	"",  -- Sherbet Land
	1,  -- Rainbow Road
	"",  -- Wario Stadium
	"",
	"",
	"",
	2,
	""}

	course.names = {
	"Mario Raceway      ",
	"Choco Mountain     ",
	"Bowser's Castle    ",
	"Banshee Boardwalk  ",
	"Yoshi Valley       ",
	"Frappe Snowland    ",
	"Koopa Troopa Beach ",
	"Royal Raceway      ",
	"Luigi Raceway      ",
	"Moo Moo Farm       ",
	"Toad's Turnpike    ",
	"Kalimari Desert    ",
	"Sherbet Land       ",
	"Rainbow Road       ",
	"Wario Stadium      ",
	"Block Fort         ",
	"Skyscraper         ",
	"Double Deck        ",
	"DK's Jungle Parkway",
	"Big Donut          "}

	savestate.load(state_file)

	course.selected_addr = 0xDC5A0
	course.number = mainmemory.read_u16_be(course.selected_addr) + 1
	course.name = course.names[course.number]
	course.col_start = course.col_addresses[course.number]
	-- course.col_fin = course.col_addr_fins[course.number]
	course.col_step = 0x2C
	course.col_attr_offset = 0x02
	course.p1_offset = 0x11
	course.p2_offset = 0x15
	course.p3_offset = 0x19
	course.tr_attr = course.track_attribute[course.number]

	-- this loads the map, just the track sections though
	load_map()

	-- kart data
	kart = {}
	kart.x_addr = 0x0F69A4
	kart.xv_addr = 0x0F69C4
	kart.y_addr = 0xF69A8
	kart.yv_addr = 0x0F69C8
	kart.z_addr = 0x0F69AC
	kart.zv_addr = 0x0F69CC
	dist_addr = 0x16328A
	kart.sin = 0xF6B04
	kart.cos = 0xF6B0C

	character_addr = 0x0DC53B
	character = mainmemory.read_u8(character_addr)

	-- object addresses
	obj = {}
	obj.addr = 0x15F9B8
	obj.stop = 0x162578
	obj.step = 0x70
	obj.x_offset = 0x18
	obj.y_offset = 0x1C
	obj.z_offset = 0x20

	-- some colors
	black  = 0xFF000000
	white  = 0xFFFFFFFF
	red    = 0xFFFF0000
	bred   = 0x60FF0000
	green  = 0xFF00FF00
	sgreen = 0xFF009900
	blue   = 0xFF0000FF
	yellow = 0xFFFFFF00
	fbox   = 0xFF00007F
	bblue  = 0x200000FF
	l_off  = 0x500000FF
	bwhite = 0x60FFFFFF
	back   = 0x40808080
	none   = 0x00000000
	b_on   = 0xFF1d2dc1
	b_off  = 0x90000000
	player = {
	0x80FF0000, -- mario
	0x0, -- luigi
	0x0, --
	0x0, --
	0x0, --
	0x0, --
	0x0, --
	0x0} --

	math.randomseed(os.time())
	box_radius = 6
	num_inputs = box_radius*box_radius*4
	max_nodes = 1000000
	fitness = 0
	gain = 0
	highest_fitness = 0
	highest_distance = 0
	global_max_fitness = 0
	global_best_genome = new_genome()
	replay_best_genome = false
	not_advanced = 20
	global_innovation = 0
	current_species = 0
	population = 200
	compatibility_threshold = 1.0
	c1 = 1
	c2 = 1
	c3 = 1
	mutate_weights_chance   = 0.25
	weight_perturbation     = 2
	-- must be at least one so all genomes have at least one gene
	mutate_structure_chance = 1
	add_node_chance         = 0.4

	clear_controller()

	-- initialize population
	initialize_population()
end -- end initialize_things

function create_form()
	form = forms.newform(250, 400, "MK64 NEAT")
	hide_net = forms.checkbox(form, "Hide Network", 5, 5)
	hide_xyz_data = forms.checkbox(form, "Hide Info", 5, 25)
	load_save_label = forms.label(form, "Save/Load file:", 5, 50)
	load_save_backup = forms.textbox(
		form, state_file.."_frequent_backup.txt", 155, 30, nil, 5, 73
		)
	-- see next_genome() function
	save_button = forms.button(form, "Save", save_here, 5, 95)
	load_button = forms.button(form, "Load", load_generation, 85, 95)
	replay_best_button = forms.button(
		form, "Replay Best", replay_best, 5, 125
		)
	restart_button = forms.button(form, "Restart", initialize_things, 85, 125)

	l_generation = forms.label(form, "Generation: 0", 5, 160)
	l_species = forms.label(form, "Species: 0", 5, 185)
	l_genome = forms.label(form, "Genome: 0", 5, 210)
	l_fitness = forms.label(form, "Fitness: 0", 5, 235)
	l_max_fitness = forms.label(form, "Max Fitness: 0", 5, 260)
	l_member = forms.label(form, "Member: ", 5, 285)

end

function game_over()
	forms.destroy(form)
end

function round(num, idp)
	local mult = 10^(idp or 0)
	return math.floor(num * mult + 0.5) / mult
end

function display_info()
	gui.drawBox(-1, 214, 320, 240, none, bwhite)
	-- gui.drawText(-2, 212, course.name, black, none)
	gui.drawText(-2, 212, "Generation:"..pop.generation, black, none)
	gui.drawText(120, 212, "Species:"..pop.current_species, black, none)
	gui.drawText(240, 212, "Genome:"..pop.current_genome, black, none)

	gui.drawText(-1, 224, "Fitness:".. round(fitness), black, none)
	gui.drawText(
		90, 224, "Max Fitness:"..round(global_max_fitness), black, none
		)
	gui.drawText(215, 224, "Member:"..pop.member.."/"..population, black, none)

	if pop.frame_count % 10 == 0 then
		forms.settext(l_generation, "Generation: "..pop.generation)
		forms.settext(l_species, "Species: "..pop.current_species)
		forms.settext(l_genome, "Genome: "..pop.current_genome)
		forms.settext(l_fitness, "Fitness: "..round(fitness))
		forms.settext(l_max_fitness, "Max Fitness: "..round(global_max_fitness))
		forms.settext(l_member, "Member: "..pop.member.."/"..population)
	end

-------------------------------------------------------------------------------
	-- gui.text(100, 0, "Distance: " .. distance, "white", "black")
	-- gui.text(0, 0, course.name, "white", "topright")

	-- gui.text(0,17, "X ".. string.format("%.3f", kart_x),"white","bottomleft")
	-- gui.text(0,2, "Xv ".. string.format("%.3f", kart_xv),"white","bottomleft")

	-- gui.text(120,17, "Y ".. string.format("%.3f", kart_y),"white","bottomleft")
	-- gui.text(120,2, "Yv ".. string.format("%.3f", kart_yv),"white","bottomleft")

	-- gui.text(240,17, "Z ".. string.format("%.3f", kart_z),"white","bottomleft")
	-- gui.text(240,2, "Zv ".. string.format("%.3f", kart_zv),"white","bottomleft")

	-- gui.text(360,17, "XYv " .. string.format("%.3f", XYspeed) .. " km/h","white","bottomleft")
	-- gui.text(360,2, "XYZv " .. string.format("%.3f", round(XYZspeed)) .. " km/h","white","topleft")

	-- gui.text(530,17, "sin " .. string.format("%.9f", k_sin),"white","bottomleft")
	-- gui.text(530,2, "cos " .. string.format("%.9f", k_cos),"white","bottomleft")
end

function handle_form()
	-- handle form options
	if not forms.ischecked(hide_net) then
		show_network()
	end

	if not forms.ischecked(hide_xyz_data) then
		display_info()
	end
end

function load_map()
	the_course = {}
	-- TODO find where the collision addresses end for each track
	for addr = course.col_start, course.col_start + 0x9000, course.col_step do
		local section = {}
		section.p1 = {}
		section.p2 = {}
		section.p3 = {}
		local the_attribute = mainmemory.read_s16_be(
			addr + course.col_attr_offset
			)
		if the_attribute == course.tr_attr then
			section.attribute = the_attribute

			local p1_addr = mainmemory.read_s24_be(addr + course.p1_offset)
			section.p1.x = mainmemory.read_s16_be(p1_addr)
			section.p1.y = mainmemory.read_s16_be(p1_addr + 0x2)
			section.p1.z = mainmemory.read_s16_be(p1_addr + 0x4)

			local p2_addr = mainmemory.read_s24_be(addr + course.p2_offset)
			section.p2.x = mainmemory.read_s16_be(p2_addr)
			section.p2.y = mainmemory.read_s16_be(p2_addr + 0x2)
			section.p2.z = mainmemory.read_s16_be(p2_addr + 0x4)

			local p3_addr = mainmemory.read_s24_be(addr + course.p3_offset)
			section.p3.x = mainmemory.read_s16_be(p3_addr)
			section.p3.y = mainmemory.read_s16_be(p3_addr + 0x2)
			section.p3.z = mainmemory.read_s16_be(p3_addr + 0x4)

			the_course[#the_course + 1] = section
		end
	end
end

function initialize_population()
	pop = new_pop()

	for i = 1, pop.size do
		local genome = new_genome()
		mutate(genome)
		speciate(genome)
	end

	refresh()
	next_genome(false)
	initialize_run(false)
	create_backup("backup_"..state_file.."_gen_0.txt")
end

function new_pop()
	local pop = {}
	pop.size = population
	pop.species = {}
	pop.generation = 1
	pop.current_species = 1
	pop.current_genome = 0
	pop.member = 0
	pop.frame_count = -1
	return pop
end

function new_species()
	local species = {}
	species.genomes = {}
	species.fitness = 0
	species.last_fitness = 0
	species.improvement_age = 0
	return species
end

function new_genome()
	local genome = {}
	-- gonna try to do this with just one genes table,
	-- instead of nodes and connections
	genome.genes = {}
	-- keep track of how many nodes are in the network (not including outputs)
	genome.num_neurons = num_inputs
	genome.fitness = 0
	genome.shared_fitness = 0
	genome.network = {}
	genome.received_trial = false
	return genome
end

function new_gene(the_in, the_out, the_weight, the_enable, the_innovation)
	local gene = {}
	gene.in_node = the_in
	gene.out_node = the_out
	gene.weight = the_weight
	gene.enable = the_enable
	gene.innovation = the_innovation
	return gene
end

function copy_all_species()
	local species_copy = {}
	for s = 1, #pop.species do
		local species = new_species()
		for g = 1, #pop.species[s].genomes do
			table.insert(
				species.genomes, copy_genome(pop.species[s].genomes[g])
				)
		end
		table.insert(species_copy, species)
	end
	return species_copy
end

function copy_genome(genome)
	g2 = new_genome()
	for g = 1, #genome.genes do
		table.insert(g2.genes, copy_gene(genome.genes[g]))
	end
	g2.num_neurons = genome.num_neurons
	g2.fitness = genome.fitness
	g2.shared_fitness = genome.shared_fitness
	g2.received_trial = genome.received_trial
	return g2
end

function copy_gene(gene)
	local g2 = {}
	g2.in_node = gene.in_node
	g2.out_node = gene.out_node
	g2.weight = gene.weight
	g2.enable = gene.enable
	g2.innovation = gene.innovation
	return g2
end

function new_neuron(genome)
	genome.num_neurons = genome.num_neurons + 1
	return genome.num_neurons
end

function new_innovation(n1, n2)
	-- TODO check for existing innovation
	global_innovation = global_innovation + 1
	-- pn(global_innovation)
	return global_innovation
end

function mutate(genome)
	-- can mutate each weight
	if math.random() < mutate_weights_chance then
		mutate_weights(genome)
	end

	-- structure mutations
	-- can add connection
	-- if math.random() <= mutate_structure_chance then
	for i = 1, math.random(1, 2) do
		add_connection(genome)
	end
	-- end

	-- can add node
	if math.random() < add_node_chance then
		for i = 1, math.random(1,1) do
			add_node(genome)
		end
	end

	-- enable / disable
	if math.random() < 0.5 then
		mutate_enable(genome)
	end
end

function mutate_weights(genome)
	-- mutate the weights
	for i = 1, #genome.genes do
		local n = math.random(-1,1)
		while n == 0 do
			n = math.random(-1,1)
		end
		genome.genes[i].weight = (
			genome.genes[i].weight + n * math.random() * weight_perturbation
			)
	end
end

function add_connection(genome)
	-- add a new connection gene with a random weight

	-- find two random neurons to connect, only one can be an input,
	-- and they cannot be connected already
	local n1
	local n2
	n1, n2 = two_random_neurons(genome)

	-- generate a new gene with random weight, and in and out neurons
	-- TODO check for existing innovation
	local new_gene = new_gene(
		n1, n2, -- in_node, out_node
		math.random(), -- weight
		true, -- enable bit
		new_innovation(n1, n2)
		)

	for k, gene in pairs(genome.genes) do
		if (gene.in_node == new_gene.in_node and
			gene.out_node == new_gene.out_node) then
			return  -- TODO make this work better so it just tries again
		end
	end

	table.insert(genome.genes, new_gene)
end

function add_node(genome)
	if #genome.genes == 0 then
		return
	end

	-- pick a connection to split
	local old_connection = genome.genes[math.random(1, #genome.genes)]
	old_connection.enable = false
	local n1 = old_connection.in_node
	local n2 = old_connection.out_node
	local new_node_id = new_neuron(genome)

	-- create two new connections
	local new_connection_1 = new_gene(n1, new_node_id,
		1.0,
		true,
		new_innovation(n1, new_node_id)
		)
	local new_connection_2 = new_gene(new_node_id, n2,
		old_connection.weight,
		true,
		new_innovation(new_node_id, n2)
		)
	genome.num_neurons = genome.num_neurons + 1
	table.insert(genome.genes, new_connection_1)
	table.insert(genome.genes, new_connection_2)
end

function mutate_enable(genome)
	for g = 1, #genome.genes do
		if math.random() < 0.3 then
			if genome.genes[g].enable then
				genome.genes[g].enable = false
			else
				genome.genes[g].enable = true
			end
		end
	end
end

function two_random_neurons(genome)
	local n1
	local n2

	local neurons = {}
	for i = 1, num_inputs do
		neurons[i] = true
	end
	for o = 1, num_buttons do
		neurons[max_nodes + o] = true
	end
	for i = 1, #genome.genes do
		if genome.genes[i].in_node > num_inputs then
			neurons[genome.genes[i].in_node] = true
		end
		if genome.genes[i].out_node > num_inputs then
			neurons[genome.genes[i].out_node] = true
		end
	end
	local num_neurons = 0
	for _,_ in pairs(neurons) do
		num_neurons = num_neurons + 1
	end

	-- choose if n2 will be output neuron or some other neuron
	if num_neurons - 9 > num_inputs then
		local excess_neurons = num_neurons - num_inputs - 9
		local rando = math.random()
		if rando < 0.33 then
			n1 = math.random(1, 144)
			n2 = math.random(145, 145 + excess_neurons)
		elseif rando > 0.33 and rando < 0.66 then
			n1 = math.random(145, 145 + excess_neurons)
			n2 = math.random(1000001, 1000009)
		else
			n1 = math.random(1, num_neurons - 9)
			n2 = math.random(1000001, 1000009)
		end
	else -- we don't have any other neurons but outputs
		n1 = math.random(1, num_neurons - 9)
		n2 = math.random(1000001, 1000009)
	end

	return n1, n2
end

function get_neurons(genome)
	local neurons = {}
	for i = 1, num_inputs do
		neurons[i] = true
	end
	for o = 1, num_buttons do
		neurons[max_nodes + o] = true
	end
	for i = 1, #genome.genes do
		if genome.genes[i].in_node > num_inputs then
			neurons[genome.genes[i].in_node] = true
		end
		if genome.genes[i].out_node > num_inputs then
			neurons[genome.genes[i].out_node] = true
		end
	end
	return neurons
end

function speciate(baby_genome)
	local matched_a_species = false
	for i = 1, #pop.species do
		local genes1 = pop.species[i].genomes[1].genes
		local genes2 = baby_genome.genes
		if #genes2 < #genes1 then -- make sure the shorter genome is first
			genes1, genes2 = genes2, genes1
		end
		cd = compatibility_distance(genes1, genes2)
		if cd < compatibility_threshold then
			table.insert(pop.species[i].genomes, baby_genome)
			matched_a_species = true
		end
	end

	if not matched_a_species then
		local unique_species = new_species()
		table.insert(unique_species.genomes, baby_genome)
		table.insert(pop.species, unique_species)
	end
end

function compatibility_distance(genes1, genes2)
	local E = excess_genes(genes1, genes2)
	local D = disjoint_genes(genes1, genes2)
	local N = math.max(#genes1, #genes2)
	if N < 20 then N = 1 end
	local W = sum_of_weight_differences(genes1, genes2) / (
		#genes1 + #genes2 - E - D
		)
	return c1*E/N + c2*D/N + c3*W
end

function excess_genes(genes1, genes2)
	local excess = 0

	local highest_1 = 0
	for i = 1, #genes1 do
		if genes1[i].innovation > highest_1 then
			highest_1 = genes1[i].innovation
		end
	end

	local highest_2 = 0
	for i = 1, #genes2 do
		if genes2[i].innovation > highest_2 then
			highest_2 = genes2[i].innovation
		end
	end

	if highest_1 > highest_2 then
		for i = 1, #genes1 do
			if genes1[i].innovation > highest_2 then
				excess = excess + 1

			end
		end
	else
		for i = 1, #genes2 do
			if genes2[i].innovation > highest_1 then
				excess = excess + 1
			end
		end
	end

	return excess
end

function disjoint_genes(genes1, genes2)
	local disjoint = 0

	for i = 1, #genes1 do
		local found = false
		for j = 1, #genes2 do
			if genes1[i].innovation == genes2[j].innovation then
				found = true
				break
			end
		end
		if not found then
			disjoint = disjoint + 1
		end
	end

	for i = 1, #genes2 do
		local found = false
		for j = 1, #genes1 do
			if genes2[i].innovation == genes2[j].innovation then
				found = true
				break
			end
		end
		if not found then
			disjoint = disjoint + 1
		end
	end

	return disjoint
end

function sum_of_weight_differences(genes1, genes2)
	local sum_of_differences = 0

	for i = 1, #genes1 do
		for j = 1, #genes1 do
			if genes1[i].innovation == genes2[j].innovation then
				sum_of_differences = sum_of_differences + math.abs(
					genes1[i].weight - genes2[j].weight
					)
			end
		end
	end

	return sum_of_differences
end

function get_objects()
	objects = {}
	for addr = obj.addr, obj.stop, obj.step do
		local object = {}
		object.t = mainmemory.read_s16_be(addr) * 0.1

		-- hmmm
		if object.t > 1.1 and object.t < 1.3 then
			object.t = 1.2
		end
		if object.t > 0.5 and object.t < 0.7 then
			object.t = 0.6
		end
		if object.t > 0.6 and object.t < 0.8 then
			object.t = 0.7
		end

		-- make bad objects a negative value
		if object.t == 2.6 or object.t == 1.3 or
			object.t == 0.8 or object.t == 0.7 or
			object.t == 0.6 then
			object.t = -object.t
		end

		object.x = mainmemory.readfloat(addr + obj.x_offset, true)
		object.y = mainmemory.readfloat(addr + obj.y_offset, true)
		object.z = mainmemory.readfloat(addr + obj.z_offset, true)
		if object.x == object.x and object.t ~= 0 and
			object.t ~= 4.3 and in_box(object) then
			objects[#objects + 1] = object
		end
	end
end

function get_box()
	box = {}
	box.tl    = {}
	box.tr    = {}
	box.bl    = {}
	box.br    = {}
	box.tl.x  = 359 * k_cos + 180 * k_sin + kart_x
	box.tl.z  = 359 * k_sin - 180 * k_cos + kart_z
	box.bl.x  =  -1 * k_cos + 180 * k_sin + kart_x
	box.bl.z  =  -1 * k_sin - 180 * k_cos + kart_z
	box.br.x  =  -1 * k_cos - 180 * k_sin + kart_x
	box.br.z  =  -1 * k_sin + 180 * k_cos + kart_z
	box.tr.x  = 359 * k_cos - 180 * k_sin + kart_x
	box.tr.z  = 359 * k_sin + 180 * k_cos + kart_z
	-- gui.text(
	-- 	220,130, string.format("%.3f", box.tl.x) .. ",Y," .. string.format(
	-- 		"%.3f", box.tl.z
	-- 		),"white","topleft")
	-- gui.text(
	-- 	480,130, string.format("%.3f", box.tr.x) .. ",Y," .. string.format(
	-- 		"%.3f", box.tr.z),
	-- 	"white","topleft")
	-- gui.text(
	-- 	220,430, string.format("%.3f", box.bl.x) .. ",Y," .. string.format(
	-- 		"%.3f", box.bl.z),
	-- 	"white","topleft")
	-- gui.text(
	-- 	480,430, string.format("%.3f", box.br.x) .. ",Y," .. string.format(
	-- 		"%.3f", box.br.z),
	-- 	"white","topleft")
end

function in_box(o)
	-- top left to bottom left
	local a = -(box.bl.z - box.tl.z)
	local b = box.bl.x - box.tl.x
	local c = -(a * box.tl.x + b * box.tl.z)
	local b1 = s_sign(o, a, b, c) < 0
	-- pn(b1)

	-- bottom left to bottom right
	a = -(box.br.z - box.bl.z)
	b = box.br.x - box.bl.x
	c = -(a * box.bl.x + b * box.bl.z)
	local b2 = s_sign(o, a, b, c) < 0

	-- bottom right to top right
	a = -(box.tr.z - box.br.z)
	b = box.tr.x - box.br.x
	c = -(a * box.br.x + b * box.br.z)
	local b3 = s_sign(o, a, b, c) < 0

	-- top right to top left
	a = -(box.tl.z - box.tr.z)
	b = box.tl.x - box.tr.x
	c = -(a * box.tr.x + b * box.tr.z)
	local b4 = s_sign(o, a, b, c) < 0

	return ((b1 == b2) and (b2 == b3) and (b3 == b4))
end

function s_sign(o, a, b, c)
	return a * o.x + b * o.z + c
end

function get_tiles()
	tiles = {}
	for z = -165, 165, 30 do
		for x = 344, 13, -30 do
			local tile = {}
			tile.n = #tiles + 1
			tile.x = x * k_cos - z * k_sin + kart_x
			tile.z = x * k_sin + z * k_cos + kart_z
			tile.t = get_tile_attribute(tile.x, tile.z)
			tiles[#tiles + 1] = tile
		end
	end
end

function get_tile_attribute(x, z)
	-- could be an object, could be track, could be something else

	-- objects
	for i, o in ipairs(objects) do
		local o_box = get_o_box(o)
		if in_o_box(x, z, o_box) then
			return o.t
		end
	end

	-- track
	for i, section in ipairs(the_course) do
		if in_section(x, z, section) then
			return section.attribute
		end
	end

	-- something else
	return -1
end

function get_o_box(o)
	local o_box = {}
	o_box.tl = {}
	o_box.bl = {}
	o_box.br = {}
	o_box.tr = {}
	o_box.tl.x =  15 * k_cos + 15 * k_sin + o.x
	o_box.tl.z =  15 * k_sin - 15 * k_cos + o.z
	o_box.bl.x = -15 * k_cos + 15 * k_sin + o.x
	o_box.bl.z = -15 * k_sin - 15 * k_cos + o.z
	o_box.br.x = -15 * k_cos - 15 * k_sin + o.x
	o_box.br.z = -15 * k_sin + 15 * k_cos + o.z
	o_box.tr.x =  15 * k_cos - 15 * k_sin + o.x
	o_box.tr.z =  15 * k_sin + 15 * k_cos + o.z
	o_box.y = o.y
	return o_box
end

function in_o_box(x, z, o_box)
	local o = {}
	o.x = x
	o.z = z

	-- top left to bottom left
	local a = -(o_box.bl.z - o_box.tl.z)
	local b = o_box.bl.x - o_box.tl.x
	local c = -(a * o_box.tl.x + b * o_box.tl.z)
	local b1 = s_sign(o, a, b, c) < 0

	-- bottom left to bottom right
	a = -(o_box.br.z - o_box.bl.z)
	b = o_box.br.x - o_box.bl.x
	c = -(a * o_box.bl.x + b * o_box.bl.z)
	local b2 = s_sign(o, a, b, c) < 0

	-- bottom right to top right
	a = -(o_box.tr.z - o_box.br.z)
	b = o_box.tr.x - o_box.br.x
	c = -(a * o_box.br.x + b * o_box.br.z)
	local b3 = s_sign(o, a, b, c) < 0

	-- top right to top left
	a = -(o_box.tl.z - o_box.tr.z)
	b = o_box.tl.x - o_box.tr.x
	c = -(a * o_box.tr.x + b * o_box.tr.z)
	local b4 = s_sign(o, a, b, c) < 0

	local b5 = o_box.y > kart_y - 74 and o_box.y < kart_y + 74

	return ((b1 == b2) and (b2 == b3) and (b3 == b4)) and b5
end

function in_section(x, z, s)
	local b1 = t_sign(x, z, s.p1,   s.p2)    < 0
	local b2 = t_sign(x, z, s.p2,   s.p3)  < 0
	local b3 = t_sign(x, z, s.p3, s.p1)    < 0
	local b4 = s.p1.y   > kart_y - 74 and s.p1.y   < kart_y + 74
	local b5 = s.p2.y   > kart_y - 74 and s.p2.y   < kart_y + 74
	local b6 = s.p3.y > kart_y - 74 and s.p3.y < kart_y + 74
	local b7 = ((b1 == b2) and (b2 == b3)) and b4 and b5 and b6
	return b7
end

function t_sign(x, z, p2, p3)
	return (x - p3.x) * (p2.z - p3.z) - (p2.x - p3.x) * (z - p3.z)
end

function get_inputs()
	get_box()
	get_objects()
	get_tiles()
end

function get_outputs()
	get_inputs()
	local outputs = evaluate_network()
	return outputs
end

function basic_ai()
	-- this demonstrates how simple a solution can be
	-- an interesting this about this is that it will play out the same every
	-- single time. the game may seem random, but if the input to the game is
	-- always the same, then the game will always play exactly the same.
	-- the opponents will always drive in the same place, the same items will
	-- received from item boxes, etc.
	get_inputs()

	local outputs = {}
	local attr = course.track_attribute[course.number]

	clear_controller()
	outputs = controller

	local button_a = "P1 A"
	outputs[button_a] = true

	local button_z = "P1 Z"
	if pop.frame_count % 23 == 0 then
		outputs[button_z] = true
	else
		outputs[button_z] = false
	end

	local button_left = "P1 A Left"
	local button_right = "P1 A Right"

	if tiles[39].t == attr or tiles[31].t == attr then
		outputs[button_left] = true
	else
		outputs[button_left] = false
	end

	if tiles[99].t == attr or tiles[115].t == attr then
		outputs[button_right] = true
		outputs[button_left] = false
	else
		outputs[button_right] = false
	end

	return outputs
end

function show_network()
	local text_color = white
	local cell_border = black
	local cell_fill = white
	local line_color = back
	local object_color = black
	local track_cell_border = black
	local track_cell_fill = white

	local genome = {}
	if replay_best_genome then
		genome = copy_genome(global_best_genome)
	else
		genome = pop.species[pop.current_species].genomes[pop.current_genome]
	end

	-- aerial view
	-- scale is 6
	gui.drawBox( -- 60x60 box
		92-box_radius*5-1, 80-box_radius*5-1,
		92+box_radius*5+1, 80+box_radius*5+1,
		black, bblue)
	local i = 1
	for x = -box_radius, box_radius - 1 do -- the tiles
		for z = -box_radius, box_radius - 1 do
			cell_border = black
			if tiles[i].t == course.tr_attr then  -- track attribute
				cell_fill = white
			elseif tiles[i].t == -2.6 then  -- tree
				cell_fill = green
			elseif tiles[i].t == 1.2 then  -- item box
				cell_fill = blue
			elseif tiles[i].t == -0.7 then  -- green shell
				cell_fill = sgreen
			elseif tiles[i].t == -0.8 then  -- red shell
				cell_fill = red
			elseif tiles[i].t == -1.3 then  -- fake item box
				cell_fill = fbox
			elseif tiles[i].t == -0.6 then  -- banana
				cell_fill = yellow
			elseif tiles[i].t > 0 then  -- unknown
				cell_fill = black
				pn('unknown object: '..tiles[i].t)
			else
				cell_border = none
				cell_fill = none
			end
			gui.drawBox(
				92+x*5, 80+z*5,
				92+x*5+5, 80+z*5+5,
				cell_border, cell_fill
				)
			i = i + 1
		end
	end

	local cells = {}
	local cell = {}

	local i = 1
	for x = -box_radius, box_radius - 1 do -- the tiles
		for y = -box_radius, box_radius - 1 do
			cell = {}
			cell.x = 95+x*5
			cell.y = 83+y*5
			cell.activated = false -- no activation needed on these nodes
			cells[i] = cell
			i = i + 1
		end
	end

	-- buttons
	gui.drawBox(275, 38, 315, 129, black, bblue)
	for o, b in ipairs(button_input_names) do
		cell = {}
		cell.x = 270
		cell.y = 34+10*o
		if controller[b] == true then
			cell.activated = true
			text_color = white
			cell_border = black
			cell_fill = white
		else
			cell.activated = false
			text_color = b_off
			cell_border = b_off
			cell_fill = back
		end
		cells[o + max_nodes] = cell
		gui.drawText(275, 26+10*o, button_actual_names[o], text_color, 9)
		gui.drawBox(268, 32+10*o, 272, 36+10*o, cell_border, cell_fill)

		-- this is for the basic AI
		-- if o == 5 and controller[b] == true then
		-- 	gui.drawLine(80, 49, 270, 84, blue)
		-- elseif o == 5 and controller[b] == false then
		-- 	gui.drawLine(80, 49, 270, 84, bblue)
		-- else
		-- 	gui.drawLine(80, 49, 270, 84, none)
		-- end

		-- if o == 6 and controller[b] == true then
		-- 	gui.drawLine(105, 49, 270, 92, blue)
		-- elseif o == 6 and controller[b] == false then
		-- 	gui.drawLine(105, 49, 270, 92, bblue)
		-- else
		-- 	gui.drawLine(105, 49, 270, 92, none)
		-- end
	end

	for n, node in pairs(current_network.nodes) do
		if n > num_inputs and n <= max_nodes then
			cell = {}
			cell.x = 160
			cell.y = 50
			if node.value > 1 then
				cell.activated = true
			else
				cell.activated = false
			end
			cells[n] = cell
		end
	end

	-- try to reset the x and y of the hidden nodes so the network looks nice
	-- this code closely follows sethbling's code
	for i = 1, 4 do
		for _, gene in pairs(genome.genes) do
			if gene.enable then
				local in_cell = cells[gene.in_node]
				local out_cell = cells[gene.out_node]
				if gene.in_node > num_inputs and
					gene.in_node <= max_nodes then
					in_cell.x = 0.75 * in_cell.x + 0.25 * out_cell.x
					if in_cell.x >= out_cell.x then
						in_cell.x = in_cell.x - 40
					end
					if in_cell.x < 150 then
						in_cell.x = 150
					end

					if in_cell.x > 260 then
						in_cell.x = 260
					end
					in_cell.y = 0.75*in_cell.y + 0.25*out_cell.y
				end
				if gene.out_node > num_inputs and
					gene.out_node <= max_nodes then
					out_cell.x = 0.25 * in_cell.x + 0.75 * out_cell.x
					if in_cell.x >= out_cell.x then
						out_cell.x = out_cell.x + 40
					end
					if out_cell.x < 150 then
						out_cell.x = 150
					end
					if out_cell.x > 260 then
						out_cell.x = 260
					end
					out_cell.y = 0.25 * in_cell.y + 0.75 * out_cell.y
				end
			end -- if enabled
		end -- for loop
	end -- do 4 times

	-- draw hidden nodes, and connections
	for i, cell in pairs(cells) do
		if i > num_inputs and i <= max_nodes then
			if cell.activated then
				cell_border = black
				cell_fill = white
			else
				cell_border = b_off
				cell_fill = back
			end
			gui.drawBox(
				cell.x - 2, cell.y - 2,
				cell.x + 2, cell.y + 2,
				cell_border, cell_fill
				)
		end
	end

	-- draw connections
	for _, gene in pairs(genome.genes) do
		if gene.enable then
			local in_cell = cells[gene.in_node]
			local out_cell = cells[gene.out_node]

			if out_cell.activated then
				line_color = red
			else
				line_color = bred
			end

			gui.drawLine(
				in_cell.x, in_cell.y,
				out_cell.x, out_cell.y,
				line_color
				)
		end
	end

	-- this is the kart
	gui.drawBox(90,106,94,110,none,player[character])
end

function save_here()
	local file_name = forms.gettext(load_save_backup)
	create_backup(file_name)
end

function load_generation()
	local file_name = forms.gettext(load_save_backup)
	load_backup(file_name)
end

function replay_best()
	save_here()
	load_generation()
	replay_best_genome = true
	initialize_run(true)
end

function create_backup(file_name)
	local file = assert(io.open(file_name, "w"))

	-- first save the best genome
	file:write(global_best_genome.fitness.." ")
	file:write(global_best_genome.num_neurons.." ")
	file:write(#global_best_genome.genes.. "\n")
	for g, gene in pairs(global_best_genome.genes) do
		file:write(gene.in_node.." ")
		file:write(gene.out_node.." ")
		file:write(gene.weight.." ")
		file:write(gene.innovation.." ")
		if gene.enable then
			file:write("1\n")
		else
			file:write("0\n")
		end
	end

	-- then save the entire population
	file:write(pop.generation.." ")
	file:write(global_max_fitness.." ")
	file:write(#pop.species.."\n")
	for s, species in pairs(pop.species) do
		file:write(species.fitness.." ")
		file:write(species.improvement_age.." ")
		file:write(#species.genomes.."\n")
		for g, genome in pairs(species.genomes) do
			file:write(genome.fitness.." ")
			file:write(genome.num_neurons.." ")
			if genome.received_trial then
				file:write("1 ")
			else
				file:write("0 ")
			end
			file:write(#genome.genes.."\n")
			for h, gene in pairs(genome.genes) do
				file:write(gene.in_node.." ")
				file:write(gene.out_node.." ")
				file:write(gene.weight.." ")
				file:write(gene.innovation.." ")
				if gene.enable then
					file:write("1\n")
				else
					file:write("0\n")
				end
			end
		end
	end

	file:close()
end

function load_backup(file_name)
	local file = assert(io.open(file_name, "r"))

	-- first read the best genome
	global_best_genome = {}
	global_best_genome = new_genome()
	local num_genes = 0
	global_best_genome.fitness,
	global_best_genome.num_neurons,
	num_genes = file:read("*number", "*number", "*number")
	for g = 1, num_genes do
		local genes = new_gene()
		table.insert(global_best_genome.genes, genes)
		genes.in_node,
		genes.out_node,
		genes.weight,
		genes.innovation,
		genes.enable = file:read(
			"*number", "*number", "*number", "*number", "*number"
			)
		if genes.enable == 1 then
			genes.enable = true
		else
			genes.enable = false
		end
	end

	-- then read the rest of the population
	pop = {}
	pop = new_pop()
	local num_species
	pop.generation,
	global_max_fitness,
	num_species = file:read("*number", "*number", "*number")
	for s = 1, num_species do
		local species = new_species()
		table.insert(pop.species, species)
		local num_genomes
		species.fitness,
		species.improvement_age,
		num_genomes = file:read("*number", "*number", "*number")
		for g = 1, num_genomes do
			local genome = new_genome()
			table.insert(species.genomes, genome)
			local received_trial
			genome.fitness,
			genome.num_neurons,
			received_trial,
			num_genes = file:read(
				"*number", "*number", "*number", "*number"
				)
			if received_trial == 1 then
				genome.received_trial = true
			else
				genome.received_trial = false
			end
			for h = 1, num_genes do
				local gene = new_gene()
				table.insert(genome.genes, gene)
				gene.in_node,
				gene.out_node,
				gene.weight,
				gene.innovation,
				gene.enable = file:read(
					"*number", "*number", "*number", "*number", "*number"
					)
				if gene.enable == 1 then
					gene.enable = true
				else
					gene.enable = false
				end
			end -- end gene loop
		end -- end genome loop
	end -- end species loop

	file:close()

	-- we need to advance to the genome we were on when we saved this file
	pop.current_species = 1
	pop.current_genome = 1
	pop.member = 1
	local received_trial = true
	while received_trial do
		next_genome(false)
		local species = pop.species[pop.current_species]
		local genome = species.genomes[pop.current_genome]
		received_trial = genome.received_trial
	end

	initialize_run(false)
end

function is_dead()
	local species = pop.species[pop.current_species]
	local genome = species.genomes[pop.current_genome]

	if distance < 1 then
		fitness = XYZspeed * 0.001
	elseif distance > highest_distance then
		highest_distance = distance
		gain = fitness - distance
		if gain > 0 then
			fitness = distance + gain + round(XYZspeed / 25)
		else
			fitness = distance + round(XYZspeed / 25)
		end
	end

	if fitness > highest_fitness then
		highest_fitness = fitness
		genome.fitness = round(highest_fitness)
		not_advanced = 20
	end

	if fitness > species.fitness then
		species.fitness = fitness
	end

	if fitness > global_max_fitness then
		global_max_fitness = highest_fitness
	end

	 -- cap the frame count bonus
	if pop.frame_count < 1250 then
		advanced = pop.frame_count * 0.2
	else
		advanced = 250
	end
	not_advanced = not_advanced - 1

	if advanced + not_advanced <= 0 then
		genome.received_trial = true
		if replay_best_genome then
			replay_best_genome = false
			load_backup(state_file.."_frequent_backup.txt")
		end
		return true
	end

	return false
end

function clear_controller()
	controller = {}
	for i = 1, #button_input_names do
		local button = button_input_names[i]
		controller[button] = false
	end
end

function remove_under_performers()
	for s = 1, #old_pop.species do
		table.sort(old_pop.species[s].genomes, function(a,b)
			return (a.fitness > b.fitness)
		end)
		-- retain the top 20% to be parents
		local stop = round(#old_pop.species[s].genomes * 0.2)
		if stop < 2 then stop = 2 end
		for g = #old_pop.species[s].genomes, stop, -1 do
			table.remove(old_pop.species[s].genomes)
		end
	end
end

function remove_non_improvers()
	-- drop species that haven't received an improved fitness in 4 generations
	local not_killed_off = {}

	for s = 1, #old_pop.species do
		if old_pop.species[s].fitness > old_pop.species[s].last_fitness then
			old_pop.species[s].last_fitness = old_pop.species[s].fitness
			old_pop.species[s].improvement_age = 0
		else
			old_pop.species[
			s
			].improvement_age = old_pop.species[s].improvement_age + 1
		end

		if old_pop.species[s].improvement_age < 4 or
			old_pop.species[s].fitness >= global_max_fitness then
			table.insert(not_killed_off, old_pop.species[s])
		end
	end

	old_pop.species = not_killed_off
end

function adjust_fitnesses()
	for s = 1, #old_pop.species do
		for g = 1, #old_pop.species[s].genomes do
			local species = old_pop.species[s]
			local genome = species.genomes[g]
			genome.fitness = genome.fitness / #species.genomes
		end
	end
end

function calculate_average_fitness()
	local sum = 0
	for s = 1, #old_pop.species do
		for g = 1, #old_pop.species[s].genomes do
			sum = sum + old_pop.species[s].genomes[g].fitness
		end
	end
	return sum / population
end

function calculate_spawn_levels()
	local spawn_total = 0 -- debug
	local average_fitness = calculate_average_fitness()
	for s = 1, #old_pop.species do
		local species = old_pop.species[s]
		species.spawn_number = 0
		for g = 1, #old_pop.species[s].genomes do
			local genome = species.genomes[g]
			genome.spawn_number = genome.fitness / average_fitness
			species.spawn_number = species.spawn_number + genome.spawn_number
		end
		species.spawn_number = round(species.spawn_number)
		if species.spawn_number > 0 then
			pn('species spawn number: '..species.spawn_number) -- debug
		end
		spawn_total = spawn_total + species.spawn_number -- debug
	end
	pn('spawn total: '..spawn_total) -- debug
end

function contains_innovation(genes, i)
	for g = 1, #genes do
		if genes[g].innovation == i then return true end
	end
	return false
end

function cross_over(g1, g2)
	local baby = new_genome()
	for g = 1, #g1.genes do
		if not contains_innovation(baby.genes, g1.genes[g].innovation) then
			table.insert(baby.genes, copy_gene(g1.genes[g]))
		end
	end
	for g = 1, #g2.genes do
		if not contains_innovation(baby.genes, g2.genes[g].innovation) then
			table.insert(baby.genes, copy_gene(g2.genes[g]))
		end
	end
	baby.num_neurons = math.max(g1.num_neurons, g2.num_neurons)
	return baby
end

function current_pop_size()
	local size = 0
	for s = 1, #pop.species do
		for g = 1, #pop.species[s].genomes do
			size = size + 1
		end
	end
	return size
end

function make_babies()
	pop.species = {}

	for s = 1, #old_pop.species do
		local chosen_best_yet = false
		local species = old_pop.species[s]
		while species.spawn_number >= 1 and current_pop_size() < population do

			if not chosen_best_yet then
				-- put the best genome in the new pop first for per
				-- species elitism (Ai book, page 395)
				local best_in_species = {}
				best_in_species.fitness = 0
				for i = 1, #species.genomes do
					if species.genomes[i].fitness > best_in_species.fitness then
						best_in_species = species.genomes[i]
					end
				end
				speciate(best_in_species)
				chosen_best_yet = true
			else
				-- only one genome in this species, so just mutate
				if #species.genomes == 1 then
					local baby = copy_genome(species.genomes[1])
					mutate(baby)
					baby.received_trial = false
					speciate(baby)
				-- enough genomes to have parents
				elseif #species.genomes > 1 then
					if math.random() < 0.8 then -- crossover chance
						local g1_i = math.random(1, #species.genomes)
						local g2_i = math.random(1, #species.genomes)
						local number_of_attempts = 5
						while g1_i == g2_i and number_of_attempts > 0 do
							g2_i = math.random(1, #species.genomes)
							number_of_attempts = number_of_attempts - 1
						end
						local baby = {}
						if g1_i ~= g2_i then
							local genome_1 = species.genomes[g1_i]
							local genome_2 = species.genomes[g2_i]
							baby = cross_over(genome_1, genome_2)
							mutate(baby)
							speciate(baby)
						else
							baby = species.genomes[g1_i]
							mutate(baby)
							speciate(baby)
						end -- if we have two different genomes
					end -- crossover chance
				end -- if 1 or more
			end -- if chosen best
			species.spawn_number = species.spawn_number - 1
		end -- end while
	end -- next species

	-- make sure the population is full
	-- TODO force this to choose from genomes that have a fitness above zero
	local i = 1
	while current_pop_size() < population do
		i = i + 1
		local k = 10
		local r_species
		local r_genome
		local winner = new_genome()
		winner.fitness = 0
		for i = 1, k do
			r_species = old_pop.species[math.random(1, #old_pop.species)]
			r_genome = copy_genome(
				r_species.genomes[math.random(1, #r_species.genomes)]
				)
			if r_genome.fitness > winner.fitness then
				winner = r_genome
			end
		end
		mutate(winner)
		winner.received_trial = false
		speciate(winner)
	end
	if i > 1 then pn("fill: "..i) end
end

function new_generation()
	-- pn('new_generation()')
	create_backup("backup_"..state_file.."_gen_"..pop.generation..".txt")

	math.randomseed(os.time())

	pop.current_species = 1
	pop.member = 1
	pop.generation = pop.generation + 1

	old_pop = {}
	old_pop.species = copy_all_species(pop.species)

	remove_under_performers()
	remove_non_improvers()
	adjust_fitnesses()
	calculate_spawn_levels()
	make_babies()
end

function next_genome(check_for_best)
	local genome = pop.species[pop.current_species].genomes[pop.current_genome]

	if check_for_best and genome.fitness > global_best_genome.fitness then
		global_best_genome = {}
		-- global_best_genome = new_genome()
		global_best_genome = copy_genome(genome)
		create_backup( -- the save button is kind of obsolete when this is here
			state_file.."_"..pop.generation.."_"..pop.current_species.."_"
			..pop.current_genome.."_best.txt"
			)
	end

	if pop.generation > 1 and pop.member % 5 == 0 then
		create_backup(state_file.."_frequent_backup.txt")
	end

	-- go to next genome, species, or generation
	pop.member = pop.member + 1
	pop.current_genome = pop.current_genome + 1
	if pop.current_genome > #pop.species[pop.current_species].genomes then
		pop.current_genome = 1
		pop.current_species = pop.current_species + 1
		if pop.current_species > #pop.species then
			new_generation()
		end
	end
end

function initialize_run(best_run)
	savestate.load(state_file)
	highest_fitness = 0
	highest_distance = 0
	fitness = 0
	gain = 0
	pop.frame_count = -1
	advanced = 0
	not_advanced = 20
	clear_controller()
	if best_run then
		current_network = create_network(global_best_genome)
	else
		current_network = create_network(
			pop.species[pop.current_species].genomes[pop.current_genome]
			)
	end
	controller = get_outputs()
end

function new_node()
	local node = {}
	node.connection_genes = {}
	node.value = 0.0
	return node
end

function create_network(genome)
	local network = {}
	network.nodes = {}

	-- create input nodes
	for i = 1, num_inputs do
		network.nodes[i] = new_node()
	end

	-- create output nodes
	for o = 1, num_buttons do
		network.nodes[max_nodes + o] = new_node()
	end
	-- console.clear()
	table.sort(genome.genes, function (a,b)
		return a.out_node < b.out_node
		end)
	-- create nodes from genes, if they don't exist yet
	for g = 1, #genome.genes do
		local gene = genome.genes[g]
		-- pn(gene)
		if gene.enable then
			-- does this gene's out node exist?
			if network.nodes[gene.out_node] == nil then
				network.nodes[gene.out_node] = new_node()
			end
			-- put this gene into it's out_node's connection_genes table so we
			-- know the weights and the values
			local node = network.nodes[gene.out_node]
			table.insert(node.connection_genes, gene)
			-- does this gene's in_node exist?
			if network.nodes[gene.in_node] == nil then
				network.nodes[gene.in_node] = new_node()
			end
		end
	end

	return network
end

function sigmoid(x)
	return 2 / (1 + math.exp(-x))
end

function evaluate_network()
	local outputs = {}

	for i = 1, num_inputs - 1 do
		current_network.nodes[i].value = tiles[i].t
	end

	for i, node in pairs(current_network.nodes) do
		local sum = 0
		for g = 1, #node.connection_genes do
			local connection = node.connection_genes[g]
			local in_value = current_network.nodes[connection.in_node].value
			sum = sum + connection.weight * in_value
		end

		if #node.connection_genes > 0 then
			node.value = sigmoid(sum)
		end
	end

	for o = 1, num_buttons do
		local button = button_input_names[o]
		if current_network.nodes[max_nodes + o].value > 1 then
			outputs[button] = true
		else
			outputs[button] = false
		end
	end

	return outputs
end

function refresh()
	-- http://tinyclouds.org/rant.html (warning: profanity)
	-- because he criticizes those who space things out nicely
	-- i don't agree with him entirely, but at least it is kind of funny
	pop.frame_count = pop.frame_count + 1

	distance = mainmemory.read_s16_be(dist_addr)

	k_sin    = mainmemory.readfloat(kart.sin,     true)
	k_cos    = mainmemory.readfloat(kart.cos,     true)

	kart_x   = mainmemory.readfloat(kart.x_addr,  true)
	kart_xv  = mainmemory.readfloat(kart.xv_addr, true) * 12
	kart_y   = mainmemory.readfloat(kart.y_addr,  true)
	kart_yv  = mainmemory.readfloat(kart.yv_addr, true) * 12
	kart_z   = mainmemory.readfloat(kart.z_addr,  true)
	kart_zv  = mainmemory.readfloat(kart.zv_addr, true) * 12

	XYspeed  = math.sqrt (kart_xv^2+kart_yv^2)
	XYZspeed = math.sqrt (kart_xv^2+kart_yv^2+kart_zv^2)
end


-------------------------------------------------------------------------------
-------------------------------------    --------------------------------------
-------------------------------------------------------------------------------
event.onexit(game_over)
game = gameinfo.getromname()
right_game = "Mario Kart 64 (USA)" == game

if right_game then
	initialize_things()
	create_form()
else
	pn("wrong game")
end

while right_game do
	refresh()

	if pop.frame_count % 5 == 0 then
		clear_controller()
		-- controller = basic_ai()
		controller = get_outputs()
	end

	handle_form()
	joypad.set(controller)

	if is_dead() then
		next_genome(true)
		initialize_run(false)
	end

	emu.frameadvance()
end
