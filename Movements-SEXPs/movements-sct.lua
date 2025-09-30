--Version 3.2, released on September 30, 2025 by wookieejedi
--Requires FSO build of July 01, 2025 or newer
--Description: custom sexps and functions that allow for much easier ship movements and rotations
--Usage: custom sexps are included and listed in FRED under the LUA-Movements tab

Movements = {  --makes a global variable! This is the only global variable this script creates.
	Default_ShipRadius_is_Obstacle = 25,
	Mininum_BigShip_Radius = 10, --used to track big ships above this radius, (check excludes fighters or bombers of any size)
	Extra_SmartStop_Uses_Team_Match = true,

	SP_FaceTarget = 1,

	SP_AlignAxes = 2, 
	--good for moving/rotating the least amount

	SP_FaceAlign = 3,
	--good for rotating so nose is always facing to object somewhat, such as guns being able to hit target engine 
	--  if we are ever so slightly ahead of target then perhaps still match target so we can keep following them if they move forward
	--  so only turn 180 if more ahead then just a tiny bit (ie within 179 degree cone instead of full 180 degrees)
	SP_IsFacing_Angle = math.rad(179.9/2) --recall, is-facing function is half cone, so 180 would be full 360 
}

Movements.UseDebugMode = false 
--^set to true to enable showing 3D lines to waypoint along with extra text info 
--when targeting a ship with these movement orders

--Internal Functions

	function Movements:Initiate()

		--remember that a ship not in mission will be nil in lua sexp if input parameter is type ship 
		self.Time_Previous_Check = 0
		self.G_Time_Check_Interval = 0.1
		self.Active_Rotations = {}
		self.Active_Rotations_Sum = 0
		self.Active_Locations = {}
		self.Active_Locations_Sum = 0
		self.Active_Ships_trk_Wpts = {}
		self.Active_Ships_trk_Wpts_Sum = 0
		self.Active_Wpts_trk_Objects = {}
		self.Active_Wpts_trk_Objects_Sum = 0

		self:Clear_Custom_Ship_PausedWaypoint() --for advanced scripters to utilize 

		self.Active_Big_Ships = {}
		--separate out because ships may be okay with risking buzzing by ships of the other team
		--recall, this list is only used and checked if extra smart stop safety checks are enabled

		if ba.MultiplayerMode then
			if multi:isServer() then
				self.is_enabled = true
			else
				self.is_enabled = false
			end
		else
			self.is_enabled = true
		end

		--add any big ships at mission start to tracker list
		--ships arriving later will be added with On Ship Arrive hook
		if self.is_enabled then
			for ship in mn.getShipList() do
				self:BigShipTracker_Add(ship)
			end
		end

	end

	function Movements:Round(input_number, numDecimalPlaces) --if no number of decimals is specified then it defaults to 0

		local output
		input_number = tonumber(input_number)
		if numDecimalPlaces == nil then numDecimalPlaces = 0 end

		if numDecimalPlaces == 0 then
			output = math.floor(math.floor(input_number + 0.5))
		end

		if numDecimalPlaces > 0 then
			local mult = 10^numDecimalPlaces
			output = math.floor(input_number * mult + 0.5) / mult
		end

		return output

	end

	function Movements:SmoothStep(t, accel_factor, decel_factor)

		-- Create asymmetric smoothstep using power functions
		if (t <= 0) then return 0 end
		if (t >= 1) then return 1 end

		-- Use different powers for acceleration and deceleration phases
		if (t < 0.5) then
			-- First half: slow start followed by accelerating
			local normalized = t * 2 -- Map [0, 0.5] to [0, 1]
			local eased = math.pow(normalized, accel_factor)
			return eased * 0.5-- Map back to [0, 0.5]
		else
			-- Second half: decelerating to slow end
			local normalized = (t - 0.5) * 2 -- Map [0.5, 1] to [0, 1]
			local eased = 1 - math.pow(1 - normalized, decel_factor)
			return 0.5 + eased * 0.5 -- Map back to [0.5, 1]
		end

	end

	function Movements:Get_Distance_Linear(pos_a, pos_b, check_3d, no_squareroot)

		local dx = pos_b[1] - pos_a[1]
		local dy = pos_b[2] - pos_a[2]
		local dz = pos_b[3] - pos_a[3]

		if check_3d then
			local square_sum = dx*dx + dy*dy + dz*dz
			if no_squareroot then
				return square_sum
			else
				return math.sqrt(square_sum)
			end
		else
			local square_sum = dx*dx + dz*dz
			if no_squareroot then
				return square_sum
			else
				return math.sqrt(square_sum)
			end
		end

	end

	function Movements:Get_Distance_Angle(angle_1, angle_2) --angles in radians

		local pi = math.pi

		-- Normalize the distance to -π to π
		local normalized1 = (angle_1 + pi) % (2 * pi) - pi
		local normalized2 = (angle_2 + pi) % (2 * pi) - pi
	
		-- Calculate the shortest distance and normalize again
		local distance = normalized2 - normalized1
		return math.abs((distance + pi) % (2 * pi) - pi)

	end

	function Movements:Has_Overlap(pos_a, r_a, pos_b, r_b, check_3d)

		-- Function to check if object overlap

		-- Check if the distance is less than or equal to the sum of the radii
		local distance_squaresum = self:Get_Distance_Linear(pos_a, pos_b, check_3d, true)
		local r_sum = r_a + r_b
		return distance_squaresum <= r_sum * r_sum 

		--return In_Bounding_Box(pos_a, r_a, pos_b, r_b, check_3d)

	end

	function Movements:IsFacing_Point(ship, point, angle_threshold, skip_is_valid_check) --angle_threshold in radians

		if not skip_is_valid_check then
			if ship == nil or point == nil or angle_threshold == nil then
				return false
			end
			if not ship:isValid() then
				return false
			end
		end

		local position_diff = point - ship.Position
		local norm_diff = position_diff:getNormalized()

		--get normalized fvec of ship
		--  v1 = origin_obj_p->orient.vec.fvec;	--get fvec of me
		--  vm_vec_normalize(&v1);	--normalize fvec of me
		local ship_fvec_norm = ship:getfvec(true) --[boolean normalize]

		--get dot and cos
		--  a1 = vm_vec_dot(&v1, &v2); --dot product v1(me) v2(target) --(v1->xyz.x*v0->xyz.x)+(v1->xyz.y*v0->xyz.y)+(v1->xyz.z*v0->xyz.z);
		--  a2 = cos_f(fl_radians(angle % 360));
		local angle_1 = ship_fvec_norm:getDotProduct(norm_diff)
		local angle_2 = math.cos(angle_threshold)

		--compare
		--  if (a1 >= a2)
		--     return SEXP_TRUE;
		--  else return SEXP_FALSE;
		if angle_1 >= angle_2 then
			return true
		else
			return false
		end

	end

	function Movements:IsFacing_Object(ship, target_object, angle_threshold, skip_is_valid_check) --angle in radians, uses half cone, so 180 is full 360/everything is in view

		--validity checks
		if ship == nil or target_object == nil or angle_threshold == nil then 
			return false 
		end

		if not skip_is_valid_check then
			if not ship:isValid() or not target_object:isValid() then 
				return false 
			end
		end

		--sub out position and normalize
			--vm_vec_sub(&v2, &target_obj_p->pos, &origin_obj_p->pos); --src_09(target) - src_1(me)
			--vm_vec_normalize(&v2); --normalize
		return self:IsFacing_Point(ship, target_object.Position, angle_threshold, true)

	end

	function Movements:Print_XYZ(xyz, optional_name)

		ba.print("Location of "..tostring(optional_name).." is")
		for i,v in ipairs({"x", "y", "z"}) do
			local c = ""
			if i <= 2 then c = "," end
			ba.print(" "..v..": "..Movements:Round(v, 4)..c)
		end
		ba.print(" (in meters) with mission time "..mn.getMissionTime().." \n")

	end

	function Movements:Print_PBH(pbh, optional_name)

		ba.print("Orientation of "..tostring(optional_name).." is")
		for i,v in ipairs({"p", "b", "h"}) do
			local c = ""
			if i <= 2 then c = "," end
			ba.print(" "..v..": "..Movements:Round(math.deg(pbh[v]), 4)..c)
		end
		ba.print(" (in degrees) with mission time "..mn.getMissionTime().." \n")

	end

	function Movements:PBH_to_3x3(pbh) --input is radians

        local p, b, h = pbh.p, pbh.b, pbh.h

        local sinp = math.sin(p)
        local cosp = math.cos(p)
        local sinb = math.sin(b)
        local cosb = math.cos(b)
        local sinh_ = math.sin(h)
        local cosh_ = math.cos(h)
        local sbsh = sinb*sinh_
        local cbch = cosb*cosh_
        local cbsh = cosb*sinh_
        local sbch = sinb*cosh_

        local vals ={
            cbch + (sinp*sbsh), --1
            (sinp*cbsh) - sbch, --2
            sinh_*cosp, --3
            sinb*cosp, --4
            cosb*cosp, --5
            -sinp, --6
            sinp*sbch - cbsh,--7
            sbsh + (sinp*cbch), --8
            cosh_*cosp--9
        }

        for i,v in ipairs(vals) do
            vals[i] = self:Round(v,6)
        end

        local finalm = {{vals[1],vals[4],vals[7]},{vals[2],vals[5],vals[8]},{vals[3],vals[6],vals[9]}}

        return finalm 

	end

	function Movements:m3x3_to_PBH(m3x3) --gets PBH in radians

        local rvec = m3x3[1]
        local uvec = m3x3[2]
        local fvec = m3x3[3]

        local heading = math.atan2(fvec[1], fvec[3]) 

        local sinh = math.sin(heading)
        local cosh = math.cos(heading)
        local cosp

        if math.abs(sinh) > math.abs(cosh) then
            cosp = fvec[1] * sinh
        else
            cosp = fvec[3] * cosh
        end

        local fvec_xz_distance = math.sqrt( (fvec[1] * fvec[1]) + (fvec[3] * fvec[3]) ) --( fvec.xyz.x^2 + fvec.xyz.z^2 )^0.5

        local pitch = math.atan2(-fvec[2], fvec_xz_distance) --<gives correct pitch 

        local bank 

        if cosp == 0 then
            bank = 0
        else
            local sinb = rvec[2] / cosp
            local cosb = uvec[2] / cosp
            
            bank = math.atan2(sinb, cosb)
        end

        --ba.print("pitch: "..math.deg(pitch)..", bank:"..math.deg(bank)..", heading:"..math.deg(heading))
        return {p=pitch, b=bank, h=heading}
        
	end

	function Movements:XYZisValid(xyz_table) --in form {x=, y=, z=}

		if type(xyz_table) == "table" then
			if type(xyz_table.x) == "number" and type(xyz_table.y) == "number" and type(xyz_table.z) == "number" then
				return true
			end
		end

		return false

	end

	function Movements:PBHisValid(pbh_table) --in form {p=, b=, h=}

		if type(pbh_table) ~= "table" then 
			--ba.print("Movements Warning: PBH table is not valid...\n")
			return false
		end

		local stop = false
		for _,v in ipairs({"p", "b", "h"}) do
			if type(pbh_table[v]) ~= "number" then
				stop = true
				break
			end
		end

		if stop then 
			return false 
		else
			return true --this means it is valid
		end	

	end

	function Movements:StandardizePBH(pbh_to_normalize)  --in form {p=,b=h=}, initial comes from game so should already be normalized

        if self:PBHisValid(pbh_to_normalize) then 
            return self:m3x3_to_PBH( self:PBH_to_3x3(pbh_to_normalize) )
		else
			ba.print("Movements Error: input pbh value for function Movements : Normalize PBH() is invalid, returning input...\n")
			return pbh_to_normalize
		end

	end

	function Movements:All_XYZ_Values_Within_Threshold(location_1, location_2, threshold) --location and threshold in meters

		if location_1 == nil or location_2 == nil then 
			print("Movements Error: XYZ values are invalid for function that checks if they are withing a threshold. \n")
			return false 
		end

		threshold = threshold or 0.01

		return self:Get_Distance_Linear(location_1, {location_2.x, location_2.y, location_2.z}, true) < threshold

	end

	function Movements:All_PBH_Values_Within_Threshold(orientation_1, orientation_2, threshold) --orientations and threshold in radians

		if orientation_1 == nil or orientation_2 == nil then 
			print("Movements Error: PBH values are invalid for function that checks if they are withing a threshold. \n")
			return false 
		end

		--set threshold default (tests work with all the following)
			--1 degree = 0.0174532925 rad
			--0.5 degree = 0.00872665 rad
			--0.25 degree = 0.004363323 rad
		threshold = threshold or 0.0001

		local values_equal = true
		for _, v in ipairs({"p", "b", "h"}) do
			if self:Get_Distance_Angle(orientation_1[v], orientation_2[v]) > threshold then
				values_equal = false
				break
			end
		end

		return values_equal

	end

	function Movements:Get_Name_from_Ship_or_Wpt_Obj(obj)

		local object_name

		if obj ~= nil and obj:isValid() then

			local obj_breed = obj:getBreedName()

			if obj_breed == "Ship" then
				object_name = obj.Name
			elseif obj_breed == "Waypoint" then
				local waypoint_list = obj:getList()
				if waypoint_list ~= nil and waypoint_list:isValid() then
					--tostring on waypoints does not work, so use a workaround for now
					--get signature of object and loop through all waypoints until we find a match, then save the name
					local num_waypoints = #waypoint_list
					local sig_obj = obj:getSignature()
					for i=1,num_waypoints do
						local wypt = waypoint_list[i]
						if wypt ~= nil and wypt:isValid() and wypt:getSignature() == sig_obj then
							object_name = waypoint_list.Name..":"..tostring(i)
						end
					end
				end
			end

		end

		return object_name

	end

	function Movements:Get_Ship_or_Wpt_Obj_from_Name(objectname)

		if type(objectname) ~= "string" or objectname == "" then 
			ba.print("Movements Error: nil or empty object name provided to function for getting ship_or_waypoint object from name...\n")
			return nil 
		end

		local function check_get_Waypoint(obj_name)

			local object_wp

			--if not ship then perhaps waypoint
			--first need to separate path name and path point i

			local wp_path_name
			local wp_point_i

			if obj_name == nil then
				return nil
			end

			local index = obj_name:find(":", 0, true)
			if index ~= nil then
				wp_path_name = obj_name:sub(1, index - 1)
				local wp_point_i_str = obj_name:sub(index+1, #obj_name)
				if wp_point_i_str ~= nil then 
					wp_point_i = tonumber(wp_point_i_str)
				end
			end

			--might have been supplied with waypoint path name
			--so use object name then check if waypoint path actually valid
			if wp_path_name == nil then
				wp_path_name = obj_name
				wp_point_i = 1
			end

			--set and check waypoint path and point
			local wp_path = mn.WaypointLists[wp_path_name]

			if wp_path ~= nil and wp_path:isValid() and wp_point_i ~= nil and wp_path[wp_point_i] ~= nil and wp_path[wp_point_i]:isValid() then
				object_wp = wp_path[wp_point_i]
			end

			if object_wp == nil then
				ba.print("Movements Error: nil or empty found for function for getting check_get_Waypoint...\n")
			end

			return object_wp

		end

		--check if object is ship or waypoint
		local ship = mn.Ships[objectname]
		if ship ~= nil and ship:isValid() then --this isValid() check is critical
			return ship
		else
			return check_get_Waypoint(objectname)
		end

	end

	function Movements:GetFinal_XYZ(ship, final_input_xyz, objecttarget_name, is_relative) --final_input_xyz in {x=,y=,z=}

		if ship == nil then return nil end 
		if not ship:isValid() then return nil end
		if not self:XYZisValid(final_input_xyz) then return nil end

		--if no target object set then return input
		--if target object is set and it isn't present then return nil to avoid moving to something that is not present
		--  ie has to be separate return checks to avoid case where there is a target object defined but it is not present
		--  it would use the relative coordinates without the target ship
		if type(objecttarget_name) ~= "string" then
			return {x = final_input_xyz.x, y = final_input_xyz.y, z = final_input_xyz.z}
		end

		--if target object corresponds to a ship in mission 
		--at this point already know target object is a string
		local target_object = self:Get_Ship_or_Wpt_Obj_from_Name(objecttarget_name)

		--if target object does not correspond to ship in mission (ie not arrived or dod) then don't do anything
		if target_object == nil then return end
		if not target_object:isValid() then return nil end

		--if target valid check which type of final xyz is needed
		local target_loc = target_object.Position
		if target_loc == nil then
			return nil 
		end

		if is_relative then 
			local new_vec = target_loc + target_object.Orientation:unrotateVector(ba.createVector(final_input_xyz.x, final_input_xyz.y, final_input_xyz.z))
			return {
				x = new_vec.x, 
				y = new_vec.y, 
				z = new_vec.z
			}
		else
			return {
				x = final_input_xyz.x + target_loc.x, 
				y = final_input_xyz.y + target_loc.y, 
				z = final_input_xyz.z + target_loc.z
			}
		end

	end

	function Movements:GetFinal_PBH(ship, final_input_pbh, objecttarget_name, special_override_id) --final_input_pbh in {p=,b=,h=}

		if ship == nil then return nil end 
		if not ship:isValid() then return nil end
		if not self:PBHisValid(final_input_pbh) then return nil end

		--if no target object set then return input
		--if target object is set and it isn't present then return nil to avoid rotating to something that is not present
		--  ie has to be separate return checks to avoid case where there is a target object defined but it is not present
		--  it would use the relative coordinates without the target ship
		if type(objecttarget_name) ~= "string" then
			return {p = final_input_pbh.p, b = final_input_pbh.b, h = final_input_pbh.h}
		end

		special_override_id = special_override_id or -1

		--if target object corresponds to a ship in mission 
		--at this point already know target object is a string
		local target_object = self:Get_Ship_or_Wpt_Obj_from_Name(objecttarget_name)

		--if target object does not correspond to ship in mission (ie not arrived or dod) then don't do anything
		if target_object == nil then return end
		if not target_object:isValid() then return nil end

		--if target valid check which type of final pbh is needed
		local target_or = target_object.Orientation
		if target_or == nil then
			return nil 
		end

		if special_override_id == self.SP_FaceTarget then
			--face to target, so do that math
			local position_diff = target_object.Position - ship.Position
			local norm_diff = position_diff:getNormalized()
			local d_pbh = norm_diff:getOrientation()

			return self:StandardizePBH({p = d_pbh.p, b = d_pbh.b, h = d_pbh.h})
		end

		if special_override_id == self.SP_AlignAxes then
			--align to target axis, can be same orientation or 180 offset, whichever is smaller/less work
			--prep orientations
			local my_pbh = ship.Orientation
			local target_pbh_180 = self:StandardizePBH({p = target_or.p, b = target_or.b, h = target_or.h + math.pi}) --math.pi = math.rad(180)

			--compare differences
			local ad_to_target_pbh = 0
			local ad_to_target_pbh180 = 0
			for _,v in ipairs({"p", "b", "h"}) do
				ad_to_target_pbh = ad_to_target_pbh + self:Get_Distance_Angle(my_pbh[v], target_or[v])
				ad_to_target_pbh180 = ad_to_target_pbh180 + self:Get_Distance_Angle(my_pbh[v], target_pbh_180[v])
			end
			local closer_pbh
			if ad_to_target_pbh <= ad_to_target_pbh180 then
				closer_pbh = target_or
			else
				closer_pbh = target_pbh_180
			end

			--return (recall both options are already normalized)
			return {p = closer_pbh.p, b = closer_pbh.b, h = closer_pbh.h}

		end

		if special_override_id == self.SP_FaceAlign then
			if self:IsFacing_Object(target_object, ship, self.SP_IsFacing_Angle, true) then
				--target object is facing us, so we are ahead of target object 
				--so if we aligned to target PBH then target could hit our engines b/c they are behind us
				--so we should face object by using target PBH +180
				return self:StandardizePBH({p = target_or.p, b = target_or.b, h = target_or.h + math.pi}) --math.pi = math.rad(180)
			else
				--target object is not facing us, so we are behind target object
				--so if we aligned to target PBH then we could hit their engines b/c they are ahead of us
				--so already will face if we match PBH
				return {p = target_or.p, b = target_or.b, h = target_or.h}
			end

		end

		if special_override_id == -1 then
			--target is relative with no special override, so add pbh
			--remember this is in radians
			--make sure to normalize to what the game uses
			return self:StandardizePBH({
					p = target_or.p + final_input_pbh.p, 
					b = target_or.b + final_input_pbh.b, 
					h = target_or.h + final_input_pbh.h
				})
		end

		--if still here make sure to return nil 
		return nil

	end

	function Movements:WaypointName(waypointpath_name, waypoint_i)

		return waypointpath_name .. ":" .. waypoint_i

	end

	function Movements:Set_Obj1_Pos_Relative_to_Obj2(obj1_to_set_name, obj2_relative_name, offset_tbl, is_relative_to_obj2_pbh) --offset_tbl in form {0, 0, 0}

		local object_to_set = self:Get_Ship_or_Wpt_Obj_from_Name(obj1_to_set_name)
		local source_target = self:Get_Ship_or_Wpt_Obj_from_Name(obj2_relative_name)

		if object_to_set == nil or source_target == nil then 
			return 
		end

		local offset
		if type(offset_tbl) == "table" and #offset_tbl == 3 then
			offset = offset_tbl
		else
			offset = {0, 0, 0}
		end

		local new_vec
		if is_relative_to_obj2_pbh then
			new_vec = source_target.Position + source_target.Orientation:unrotateVector(ba.createVector(offset[1], offset[2], offset[3]))
		else
			new_vec = ba.createVector(source_target.Position[1] + offset[1], source_target.Position[2] + offset[2], source_target.Position[3] + offset[3])
		end

		object_to_set.Position = ba.createVector(new_vec[1], new_vec[2], new_vec[3])

	end

	function Movements:GetMatchingOrder_i(ship, removing_order_priority, removing_order_string, target_of_removing_order_string) --currently supported are "ai-play-dead-persistent" and "ai-waypoints-once"

		local matching_order_i

		-- Note, if give_order and then remove_order called in same frame, remove_order will return nil
			-- b/c FSO will given an order, then the next frame process and assign a target.
		-- For example, run_ship_track_waypoint first removes orders, then gives order.
		-- But if run_waypoint_track_ship is run then run again in same frame,
			-- then the AI will have two orders in it's orders list.
			-- The internal tracking of this script properly overwrites to the second value, though.
			-- So the ship should go to the second order, 
			-- but in it's order list there will be a second order with the same PR hanging around.
			-- The ship will follow the second order given since it's added to the top of the orders list, 
			-- but when this order is met it will try to do the other order below it. 

		-- So what we should probably do is remove all orders with the matching PR and overall type...
		-- Or just clear orders..
		-- Or add some kind of optional timestamp to when order given, and if time matches then remove, and if time different then check target.. 
		-- Or just leave it alone and know that a second order could be in there...


		if self.is_enabled and ship ~= nil and ship:isValid() then
			--go through orders and find matching
			local orders = ship.Orders
			local num_ords = #orders

			--find matching
			if num_ords > 0 then
				for i=1,num_ords do
					local ord = orders[i]
					--check priority match first
					if ord ~= nil and ord:isValid() and ord.Priority == removing_order_priority then
						local ord_typ = ord:getType()
						local ord_matched = false
						--match type
						if removing_order_string == "ai-waypoints-once" and ord_typ == ORDER_WAYPOINTS_ONCE then
							--waypoint needs to ensure that waypoint path name matches
							local ord_target = ord.Target
							if ord_target ~= nil and ord_target:isValid() and ord_target:getBreedName() == "Waypoint" then
								local ord_target_wp_list = ord_target:getList()
								if ord_target_wp_list ~= nil and ord_target_wp_list:isValid() and ord_target_wp_list.Name == target_of_removing_order_string then
									ord_matched = true
								end
							end
						elseif removing_order_string == "ai-play-dead-persistent" and ord_typ == ORDER_PLAY_DEAD_PERSISTENT then
							ord_matched = true
						end
						if ord_matched then
							matching_order_i = i
							break
						end
					end
				end
			end

		end

		return matching_order_i

	end

	function Movements:RemoveGoal_Correctly(ship, removing_order_priority, removing_order_string, target_of_removing_order_string) --currently supported are "ai-play-dead-persistent" and "ai-waypoints-once"

		local matching_order_i = self:GetMatchingOrder_i(ship, removing_order_priority, removing_order_string, target_of_removing_order_string)

		--remove
		if matching_order_i ~= nil and ship.Orders[matching_order_i] ~= nil then
			ship.Orders[matching_order_i]:remove()
			--ba.print("Movements: Removing order <"..removing_order_string.."> for ship "..ship.Name.." with priority "..tostring(removing_order_priority).."...\n")
		end

	end

	function Movements:GenericSubsystem_HitsPercent(ship, subsystem_basename)

		if ship ~= nil and ship:isValid() then
			--uses submodel name
			--also, does not respect "no-aggregate" flag!
			local subsystem_basename_lc = string.lower(subsystem_basename)
			local hp_generic_total = 0
			local hp_generic_left = 0

			for subsystem in ship:getSubsystemList() do
				if subsystem ~= nil then
					local actual_sub_name_lc = string.lower(tostring(subsystem.CanonicalName))
					--make both subsystem_basename and actual_name lower case
					--if name matches then add hitpoints left to total
					if string.find(actual_sub_name_lc, subsystem_basename_lc) ~= nil then
						hp_generic_total = hp_generic_total + subsystem.HitpointsMax
						hp_generic_left = hp_generic_left + subsystem.HitpointsLeft
					end
				end
			end

			if hp_generic_total > 0 then
				if hp_generic_left <= 0 then
					return 0 
				else
					return (hp_generic_left/hp_generic_total)*100
				end
			else
				--if ss total is 0, then it can never ber destroyed, so must be at full hp
				return 100
			end
		else
			return 0
		end

	end

	function Movements:RandomPoint_On_ShipSphere(ship, return_local_coordinates)

		if ship == nil then return nil end
		if not ship:isValid() then return nil end

		local ship_radius = ship.Radius
		local ship_pos = ship.Position

		--from Brian Tung https://math.stackexchange.com/questions/1585975/how-to-generate-random-points-on-a-sphere

		local u1, u2 = ba.rand32f(), ba.rand32f() --If called with no arguments, returns a random float from [0.0, 1.0]
		local pi = math.pi

		local latitude = math.asin( (2 * u1) - 1 )
		local longitude = 2 * pi * u2

		local x = math.cos(latitude) * math.cos(longitude) * ship_radius
		local y = math.cos(latitude) * math.sin(longitude) * ship_radius 
		local z = math.sin(latitude) * ship_radius

		--ba.print(" Movements_Test: radius of sphere point to target center is "..ship_pos:getDistance(sphere_point)..", and radius is "..ship_radius.."\n")
		if return_local_coordinates then
			return ba.createVector(x, y, z)
		else
			return ba.createVector(x + ship_pos.x, y + ship_pos.y, z + ship_pos.z)
		end

	end

	function Movements:RandomPoint_In_ShipBBox(ship, return_local_coordinates)

		--finds a point within a ship's bounding box 

		--get ship and check validity
		if ship == nil then return nil end
		if not ship:isValid() then return nil end

		local base_model = ship.Class.Model

		if base_model == nil then return end
		if not base_model:isValid() then return end

		--default arguments
		if return_local_coordinates == nil then
			return_local_coordinates = false
		end

		--run calculations
		local box_min = base_model.BoundingBoxMin
		local box_max = base_model.BoundingBoxMax

		if box_min == nil or box_max == nil then return end

		local rand_pos = {0, 0, 0}
		for i=1,3 do
			rand_pos[i] = ba.rand32(self:Round(box_min[i]*100), self:Round(box_max[i]*100))/100
		end

		local rand_vec = ba.createVector(rand_pos[1], rand_pos[2], rand_pos[3])

		--return values
		if return_local_coordinates then
			return rand_vec
		else
			--rotate to be with self ship rotation
			return ship.Position + ship.Orientation:unrotateVector(rand_vec)
		end

	end

	function Movements:RandomPoint_On_ShipHull(ship, buffer_distance, return_local_coordinates)

		--finds a point on a ship's hull 

		--get ship and check validity
		if ship == nil then return nil end
		if not ship:isValid() then return nil end

		--default arguments
		if return_local_coordinates == nil then
			return_local_coordinates = false
		end
		if type(buffer_distance) ~= "number" then
			buffer_distance = 0
		end

		local ship_pos = ship.Position


		--1) Get a random point on the surface of the target ship's bounding sphere 
		local sphere_point = Movements:RandomPoint_On_ShipSphere(ship)

		--2) Run checkRayCollision from that point on the bounding sphere to the ship's center to get global position of hull intersection

		local hull_point, collision_data = ship:checkRayCollision(sphere_point, ship_pos, return_local_coordinates)
		-- vector, collision_info checkRayCollision(vector StartPoint, vector EndPoint, [boolean Local = false])
		-- Checks the collisions between the polygons of the current object and a ray. Start and end vectors are in world coordinates
		-- Returns: World collision point (local if boolean is set to true) and the specific collision info, nil if no collisions

		--3) Use that distance and line to select a new point on the intersect line, which should be touching the outside of the hull

		-- note does not work if ship has no geometry at it's origin point, like a donut ship

		-- it is expected to hit the ship/itself
		if hull_point ~= nil and collision_data ~= nil and collision_data:isValid() then

			-- face to target, so do that math
			local position_diff = ship_pos - sphere_point 
			local norm_diff = position_diff:getNormalized()
			local pbh = norm_diff:getOrientation()

			return hull_point + pbh:unrotateVector(ba.createVector(0, 0, buffer_distance))
		else
			return nil 
		end


	end

	function Movements:Get_Ship_Radius(shipname, donotround, forced_minimum) --gets radius of ship

		local final = 0

		if shipname ~= nil then
			local ship = mn.Ships[shipname]
			if ship ~= nil and ship:isValid() then
				local radius = ship.Radius
				if radius ~= nil then
					if donotround then
						final = radius
					else
						final = self:Round(radius)
					end
				end	
			end
		end

		return math.max(final, forced_minimum)

	end

	function Movements:BigShipTracker_Add(ship)

		--only add if big ship
		if ship == nil then return end
		if not ship:isValid() then return end
		if ship.Radius < self.Mininum_BigShip_Radius then return end
		local ship_obj_type = ship.Class.Type.Name
		if ship_obj_type == "fighter" or ship_obj_type == "bomber" then return end

		--big ship so add
		self.Active_Big_Ships[ship.Name] = {activebig_signature = ship:getSignature(), activebig_team = ship.Team.Name}

	end

	function Movements:BigShipTracker_Remove(shipname)

		if self.Active_Big_Ships[shipname] ~= nil then
			self.Active_Big_Ships[shipname] = nil
		end

	end


	mn.LuaSEXPs["set-bank-constant"].Action = function(bank_constant, ...)

		if not Movements.is_enabled then return end
		if #arg <= 0 then return end
		if type(bank_constant) ~= "number" then return end

		if bank_constant < 0 then 
			bank_constant = 0
		end

		for _, value in ipairs(arg) do
			local ship = value[1]
			if ship ~= nil and ship:isValid() then
				ship.Physics.BankingConstant = Movements:Round(bank_constant/100, 2)
			end
		end

	end

	mn.LuaSEXPs["set-acceleration-time"].Action = function(acceleration_time, ...)

		if not Movements.is_enabled then return end
		if #arg <= 0 then return end
		if type(acceleration_time) ~= "number" then return end

		--reset to table value if negative
		local reset_val
		if acceleration_time < 0 then 
			reset_val = true
		end

		for _, value in ipairs(arg) do
			local ship = value[1]
			if ship ~= nil and ship:isValid() then
				if reset_val then
					ship.Physics.ForwardAccelerationTime = ship.Class.ForwardAccelerationTime
				else
					ship.Physics.ForwardAccelerationTime = Movements:Round(acceleration_time/1000, 4)
				end
			end
		end

	end

	mn.LuaSEXPs["set-deceleration-time"].Action = function(deceleration_time, ...)

		if not Movements.is_enabled then return end
		if #arg <= 0 then return end
		if type(deceleration_time) ~= "number" then return end

		--reset to table value if negative
		local reset_val
		if deceleration_time < 0 then 
			reset_val = true
		end

		for _, value in ipairs(arg) do
			local ship = value[1]
			if ship ~= nil and ship:isValid() then
				if reset_val then
					ship.Physics.ForwardDecelerationTime = ship.Class.ForwardDecelerationTime
				else
					ship.Physics.ForwardDecelerationTime = Movements:Round(deceleration_time/1000, 4)
				end
			end
		end

	end

	mn.LuaSEXPs["get-waypoint-speed-cap"].Action = function(ship) --returns 0 if ship invalid

		local cap = 0
		if ship ~= nil and ship:isValid() then
			cap = ship.WaypointSpeedCap
		end

		return cap

	end

	mn.LuaSEXPs["set-pos-to-rand-pos-on-hull"].Action = function(object_to_set_oswpt, target_ship, buffer_distance) 

		--does not set if something invalid

		--validity checks
		if object_to_set_oswpt == nil then return end
		local object_to_set = object_to_set_oswpt:get()
		if object_to_set == nil then return end
		if not object_to_set:isValid() then return end

		--get random position on hull, returns nil if target invalid
		local random_pos = Movements:RandomPoint_On_ShipHull(target_ship, buffer_distance)

		--set object to that position
		if random_pos ~= nil and Movements.is_enabled then
			object_to_set.Position = random_pos
		end

	end

	mn.LuaSEXPs["set-pos-to-rand-pos-in-b-box"].Action = function(object_to_set_oswpt, target_ship)

		--does not set if something invalid

		--validity checks
		if object_to_set_oswpt == nil then return end
		local object_to_set = object_to_set_oswpt:get()
		if object_to_set == nil then return end
		if not object_to_set:isValid() then return end

		--get random position on hull, returns nil if target invalid
		local random_pos = Movements:RandomPoint_In_ShipBBox(target_ship)

		--set object to that position
		if random_pos ~= nil and Movements.is_enabled then
			object_to_set.Position = random_pos
		end

	end


	function Movements:Add_LocationMove(shipname, final_xyz, options_table) --requires xyz table in meters with {x=,y=,z=}

		--validity checks
		if not self.is_enabled then return end
		if shipname == nil then return end
		local ship = mn.Ships[shipname]
		if ship == nil then return end
		if not ship:isValid() then return end

		if type(options_table) ~= "table" then
			options_table = {}
		end

		local time_delay = options_table.SL_IN_time_delay
		local time_for_location = options_table.SL_IN_movement_time
		local play_dead_PR = options_table.SL_IN_play_dead_PR
		local targetobject_name = options_table.SL_IN_final_xyz_target_name
		local accel_value = options_table.SL_IN_acceleration_value
		local decel_value = options_table.SL_IN_deceleration_value
		local engine_dependent = options_table.SL_IN_requires_engines

		--only continue if engines are not blown out
		if engine_dependent and self:GenericSubsystem_HitsPercent(ship, "engine") <= 0 then
			return
		end

		if not self:XYZisValid(final_xyz) then
			ba.print("Movements SEXP Warning: Add LocationMove() provided with invalid final_xyz, not running move to location...\n")
			return 
		end


		--default value setting

		if type(accel_value) == "number" then
			if accel_value < 0 then
				accel_value = 1
			end
		else
			accel_value = 1
		end
		if type(decel_value) == "number" then
			if decel_value < 0 then
				decel_value = 1
			end
		else
			decel_value = 1
		end

		--set play dead order if needed, default is disabled
		--negative value turns off play dead order
		if type(play_dead_PR) ~= "number" then
			play_dead_PR = -1
		end

		--cap at 200 to avoid errors too, recall there is no floor
		if play_dead_PR > 200 then
			play_dead_PR = 200 
		end

		--set times and keep everything positive
		--all times in seconds from sexp		
		local current_time = mn.getMissionTime()
		if type(time_delay) ~= "number" then
			time_delay = 0
		end
		if time_delay < 0 then
			time_delay = 0
		end

		--negative number runs default estimated tabled speed
		if type(time_for_location) ~= "number" then
			local distance_to_move = self:Get_Distance_Linear(ship.Position, {final_xyz.x, final_xyz.y, final_xyz.z}, true)
			local max_vel = ship.Physics.VelocityMax[3] or 1
			time_for_location = (distance_to_move / max_vel) * 2 --for acceleration and deceleration 
		end

		if time_for_location < 0 then 
			time_for_location = 0
		end

		--set times, and double check default determined time for location move
		local start_time = time_delay + current_time

		local end_time = start_time + time_for_location

		--add entry using ship name as key and update total number variable
		local entry = {
			LR_OUT_shipname = shipname, 
			LR_OUT_FSO_location_initial = {}, --recall this cleared/set when location starts to
			LR_OUT_final_xyz_table = {x = final_xyz.x, y = final_xyz.y, z = final_xyz.z}, --this is the base final pbh we never want to change
			LR_OUT_FSO_location_final_updated = {}, --this adds the target's location and can change, is set when location move starts
			LR_OUT_start_time = start_time, 
			LR_OUT_end_time = end_time,
			LR_OUT_play_dead_PR = play_dead_PR,
			LR_OUT_ismoving = false,
			LR_OUT_final_xyz_target_name = targetobject_name,
			LR_OUT_final_xyz_is_relative = options_table.SL_IN_final_xyz_is_relative,
			LR_OUT_acceleration_value = accel_value,
			LR_OUT_deceleration_value = decel_value
		}

		--remove any other active location moves for this ship
		self:Remove_LocationMove(shipname, true)

		self.Active_Locations_Sum = self.Active_Locations_Sum + 1

		self.Active_Locations[shipname] = entry

	end

	function Movements:Remove_LocationMove(shipname_key, print_premature)

		if not self.is_enabled then return end
		if shipname_key == nil then return end
		local entry = self.Active_Locations[shipname_key]

		--remove any play dead orders, remove from table and update tracker totals
		if entry ~= nil then

			--remove play dead order if it was using one
			if entry.LR_OUT_play_dead_PR >= 0 then 
				self:RemoveGoal_Correctly(mn.Ships[entry.LR_OUT_shipname], entry.LR_OUT_play_dead_PR, "ai-play-dead-persistent")
			end

			if print_premature then
				ba.print("Movements: move to location for ship "..shipname_key.." is being prematurely removed ...\n")
			end

			--set to nil and update tracker variables
			self.Active_Locations[shipname_key] = nil
			self.Active_Locations_Sum = self.Active_Locations_Sum - 1

		end

	end

	function Movements:Run_LocationMove()

		local mtime = mn.getMissionTime()

		--goes through list and rotates each entry based on time
		for _, v in pairs(self.Active_Locations) do

			--only check and run if start time has come
			if mtime >= v.LR_OUT_start_time and v.LR_OUT_shipname ~= nil then
				--note: using both force stop and no chop doesn't improve final pbh matching any better

				local ship = mn.Ships[v.LR_OUT_shipname]
				if ship ~= nil and ship:isValid() then

					--overall, we should start the location move if it has not started or continue it if it has started

					local percent_done_og = (mtime - v.LR_OUT_start_time) / (v.LR_OUT_end_time - v.LR_OUT_start_time)
					local ship_loc = ship.Position

					--specified time
					local percent_done = self:SmoothStep(percent_done_og, v.LR_OUT_acceleration_value, v.LR_OUT_deceleration_value)

					if percent_done < 0 then
						percent_done = 0
					end


					if percent_done <= 1 then

						local continue_with_location = true

						--if ship location move has not started then check and start it (runs once to setup)
						--this mitigates issues with delayed starts
						if not v.LR_OUT_ismoving then

							--if we specified a final target name then check which type of location move (relative to target or absolute)

							local xyz_final = self:GetFinal_XYZ(ship, v.LR_OUT_final_xyz_table, v.LR_OUT_final_xyz_target_name, v.LR_OUT_final_xyz_is_relative)

							--^ will return pbh if no target object set
							--^ will be nil if target object_name is set but not in mission

							if xyz_final ~= nil then
								--update initial location with ships current location
								v.LR_OUT_FSO_location_initial = nil
								v.LR_OUT_FSO_location_initial = ba.createVector(ship_loc.x, ship_loc.y, ship_loc.z)

								--save whole location now
								v.LR_OUT_FSO_location_final_updated = nil
								v.LR_OUT_FSO_location_final_updated = ba.createVector(xyz_final.x, xyz_final.y, xyz_final.z)

								--run play dead if needed (ie not negative value)
								if v.LR_OUT_play_dead_PR >= 0 then
									ship:giveOrder(ORDER_PLAY_DEAD_PERSISTENT, nil, nil, v.LR_OUT_play_dead_PR/100)
								end

								--finally, set that the ship is moving
								v.LR_OUT_ismoving = true

							else
								--if the target object was set but is not in mission then we don't need to move and we can set to nil 
								continue_with_location = false
								self:Remove_LocationMove(v.LR_OUT_shipname)
							end

						--else --already moving so continue moving
						end

						if continue_with_location then
							ship.Position = v.LR_OUT_FSO_location_initial:getInterpolated(v.LR_OUT_FSO_location_final_updated, percent_done)
						end

					else --if more then percent done, then remove from list
						--set ship location to final (in theory that should already be done)
						--setting may cause a jerking motion if the off chance the preceding location didn't work, 
						--or if the ship was moving and thus had moved past final location
						--but the threshold is so small that jerkiness is not really visible (unless moving!), 
						--plus it prevents off-location build up builds with continual use
						if ship.Physics:getForwardSpeed() < 0.1 then
							local orders = ship.Orders or {}
							if #orders <= 0 then
								ship.Position = v.LR_OUT_FSO_location_final_updated
							end
						end

						--set just for consistency, technically it gets removed in the next function anyway
						v.LR_OUT_ismoving = false

						--remove and update total variable
						--  self:Print_XYZ(ship.Position, "Movements: "..ship.Name.." XYZ after being done with location move order")
						--  self:Print_XYZ(v.LR_OUT_FSO_location_final_updated, "Movements: "..ship.Name.." XYZ should be")
						self:Remove_LocationMove(v.LR_OUT_shipname)
					end

				end

			end

		end

	end

	mn.LuaSEXPs["move-to-location"].Action = function(ship, final_x, final_y, final_z, time_start_delay, time_for_effect, play_dead_priority, accel_val, decel_val)

		if ship ~= nil and ship:isValid() then

			local final_xyz = {x=final_x, y=final_y, z=final_z}
			if not Movements:XYZisValid(final_xyz) then 
				ba.print("Movements SEXP Warning: move-to-location sexp provided with invalid final_xyz, not running move to location...\n")
				return 
			end

			--add entry
			--number checks are completed in function below 
			local input_tbl = {
				SL_IN_time_delay = time_start_delay,
				SL_IN_movement_time = time_for_effect,
				SL_IN_play_dead_PR = play_dead_priority,
				SL_IN_final_xyz_target_name = nil,
				SL_IN_final_xyz_is_relative = false,
				SL_IN_acceleration_value = accel_val,
				SL_IN_deceleration_value = decel_val
			}
			Movements:Add_LocationMove(ship.Name, final_xyz, input_tbl)
		end

	end

	mn.LuaSEXPs["early-stop-move-to-location"].Action = function(ship)

		if ship ~= nil and ship:isValid() then
			Movements:Remove_LocationMove(ship.Name, true)
		end

	end


	function Movements:Add_Rotation(shipname, final_pbh, options_table) --requires pbh table in radians with {p=,b=,h=}

		--validity checks
		if not self.is_enabled then return end
		if shipname == nil then return end
		local ship = mn.Ships[shipname]
		if ship == nil then return end
		if not ship:isValid() then return end

		if type(options_table) ~= "table" then
			options_table = {}
		end

		local time_delay = options_table.SR_IN_time_delay
		local time_for_rotation = options_table.SR_IN_rotation_time
		local play_dead_PR = options_table.SR_IN_play_dead_PR
		local targetobject_name = options_table.SR_IN_final_pbh_target_name
		local special_override_final_pbh = options_table.SR_IN_final_pbh_special_override
		local engine_dependent = options_table.SR_IN_requires_engines

		--only continue if engines are not blown out
		if engine_dependent and self:GenericSubsystem_HitsPercent(ship, "engine") <= 0 then
			return
		end

		if not self:PBHisValid(final_pbh) then
			ba.print("Movements SEXP Warning: Add Rotation() provided with invalid final_pbh, not running rotation...\n")
			return 
		end


		--default value setting

		--set play dead order if needed, default is disabled
		--negative value turns off play dead order
		if type(play_dead_PR) ~= "number" then
			play_dead_PR = -1
		end

		--cap at 200 to avoid errors too, recall there is no floor
		if play_dead_PR > 200 then
			play_dead_PR = 200 
		end

		--set times and keep everything positive
		--all times in seconds from sexp		
		local current_time = mn.getMissionTime()
		if type(time_delay) ~= "number" then
			time_delay = 0
		end
		if time_delay < 0 then
			time_delay = 0
		end

		--negative number runs default value of tabled turn times
		if type(time_for_rotation) ~= "number" then
			time_for_rotation = -1
		end

		if special_override_final_pbh == nil then
			special_override_final_pbh = -1
		end


		--set times, and double check default determined time for rotation
		local start_time = time_delay + current_time

		local end_time
		--if using default rotation time then we do not precisely know the end time, so just set to -1
		if time_for_rotation < 0 then
			end_time = -1
		else 
			end_time = start_time + time_for_rotation
		end

		--add entry using ship name as key and update total number variable
		local entry = {
			SR_OUT_shipname = shipname, 
			SR_OUT_FSO_orientation_initial = {}, --recall this cleared/set when rotation starts to
			SR_OUT_final_pbh_table = self:StandardizePBH(final_pbh), --this is the base final pbh we never want to change
			SR_OUT_FSO_orientation_final_updated = {}, --this adds the target's orientation and can change, is set when rotation starts
			SR_OUT_start_time = start_time, 
			SR_OUT_end_time = end_time, -- -1 if using ai time
			SR_OUT_play_dead_PR = play_dead_PR,
			SR_OUT_isrotating = false,
			SR_OUT_final_pbh_target_name = targetobject_name,
			SR_OUT_final_pbh_override = special_override_final_pbh
		}

		--remove any other active rotations for this ship
		self:Remove_Rotation(shipname, true)

		self.Active_Rotations_Sum = self.Active_Rotations_Sum + 1

		self.Active_Rotations[shipname] = entry

	end

	function Movements:Remove_Rotation(shipname_key, print_premature)

		if not self.is_enabled then return end
		if shipname_key == nil then return end
		local entry = self.Active_Rotations[shipname_key]

		--remove any play dead orders, remove from table and update tracker totals
		if entry ~= nil then

			--remove play dead order if it was using one
			if entry.SR_OUT_play_dead_PR >= 0 then 
				self:RemoveGoal_Correctly(mn.Ships[entry.SR_OUT_shipname], entry.SR_OUT_play_dead_PR, "ai-play-dead-persistent")
			end

			if print_premature then
				ba.print("Movements: rotation for ship "..shipname_key.." is being prematurely removed ...\n")
			end

			--set to nil and update tracker variables
			self.Active_Rotations[shipname_key] = nil
			self.Active_Rotations_Sum = self.Active_Rotations_Sum - 1

		end

	end

	function Movements:Run_Rotation()

		local mtime = mn.getMissionTime()

		--goes through list and rotates each entry based on time
		for _, v in pairs(self.Active_Rotations) do

			--only check and run if start time has come
			if mtime >= v.SR_OUT_start_time and v.SR_OUT_shipname ~= nil then
				--note: using both force stop and no chop doesn't improve final pbh matching any better

				local ship = mn.Ships[v.SR_OUT_shipname]
				if ship ~= nil and ship:isValid() then

					--overall, we should start the rotation if it has not started or continue it if it has started
					--so check which method of rotation we are using (two cases), both are useful in different situations
					--  1. using specified rotation time (specified end_time)  
					--    specified rotation time is precise and works on non-AI ships
					--  2. using default ship AI turn time (end_time -1)
					--    AI turn time looks more natural and accounts for physics better

					local percent_done
					local using_ai_rotation = v.SR_OUT_end_time < 0
					local ship_ort = ship.Orientation

					if using_ai_rotation then
						--AI turn time (force min time have elapsed)
						if v.SR_OUT_isrotating and self:All_PBH_Values_Within_Threshold(ship_ort, v.SR_OUT_FSO_orientation_final_updated) then
							percent_done = 1.1 --bit hacky, but that's okay b/c with ai version we only use it to check if rotation is done
							--really this value is just to check to see if we should keep rotating per frame or not
						else
							percent_done = 0
						end
					else
						--specified rotation time
						percent_done = (mtime - v.SR_OUT_start_time) / (v.SR_OUT_end_time - v.SR_OUT_start_time)

						if percent_done < 0 then
							percent_done = 0
						end

					end

					if percent_done <= 1 then

						local continue_with_rotation = true

						--if ship rotation has not started then check and start it (runs once to setup)
						--this mitigates issues with delayed starts
						if not v.SR_OUT_isrotating then

							--if we specified a final target name then check which type of rotation (relative to target or face target)
							--function 'get final pbh' accounts for all that:
								--relative to target -> update final pbh relative to target ship's orientation:
									--for example, if final pbh was 0,0,180 and relative target is specified then 
									--get the target orientation and add on that relative 0,0,180 value 
									--to get the updated final global orientation
								--face target -> final global pbh is calculated to face target

							local pbh_final = self:GetFinal_PBH(ship, v.SR_OUT_final_pbh_table, v.SR_OUT_final_pbh_target_name, v.SR_OUT_final_pbh_override)

							--^ will return pbh if no target object set
							--^ will be nil if target object_name is set but not in mission

							--if set to simply point to the object then just get final pbh that points to that target 

							if pbh_final ~= nil then
								--update initial orientation with ships current orientation
								v.SR_OUT_FSO_orientation_initial = nil
								v.SR_OUT_FSO_orientation_initial = ba.createOrientation(ship_ort.p, ship_ort.b, ship_ort.h)

								--save whole orientation now, as full orientation to use in AI function if needed
								v.SR_OUT_FSO_orientation_final_updated = nil
								v.SR_OUT_FSO_orientation_final_updated = ba.createOrientation(pbh_final.p, pbh_final.b, pbh_final.h)

								--run play dead if needed (ie not negative value)
								if v.SR_OUT_play_dead_PR >= 0 then
									ship:giveOrder(ORDER_PLAY_DEAD_PERSISTENT, nil, nil, v.SR_OUT_play_dead_PR/100)
								end

								--finally, set that the ship is rotating
								v.SR_OUT_isrotating = true

							else
								--if the target object was set but is not in mission then we don't need to rotate and we can set to nil 
								continue_with_rotation = false
								self:Remove_Rotation(v.SR_OUT_shipname)
							end

						--else --already rotating so continue rotating
						end

						if continue_with_rotation then
							if using_ai_rotation then
								ship:turnTowardsOrientation(v.SR_OUT_FSO_orientation_final_updated)
							else
								ship.Orientation = v.SR_OUT_FSO_orientation_initial:rotationalInterpolate(v.SR_OUT_FSO_orientation_final_updated, percent_done)
							end
						end

					else --if more then percent done, then remove from list
						--set ship orientation to final (in theory that should already be done)
						--setting may cause a jerking motion if the off chance the preceding rotation didn't work, 
						--or if the ship was moving and thus had moved past final orientation
						--but the threshold is so small that jerkiness is not really visible (unless moving!), 
						--plus it prevents off-rotation build up builds with continuous PBH checks
						if ship.Physics:getForwardSpeed() < 0.1 then
							local orders = ship.Orders or {}
							if #orders <= 0 then
								ship.Orientation = v.SR_OUT_FSO_orientation_final_updated
							end
						end

						--set just for consistency, technically it gets removed in the next function anyway
						v.SR_OUT_isrotating = false

						--remove and update total variable
						--  self:Print_PBH(ship.Orientation, "Movements: "..ship.Name.." PBH after being done with rotation order")
						--  self:Print_PBH(v.SR_OUT_FSO_orientation_final_updated, "Movements: "..ship.Name.." PBH should be")
						self:Remove_Rotation(v.SR_OUT_shipname)
					end

				end

			end

		end

	end

	mn.LuaSEXPs["move-to-orientation"].Action = function(ship, final_p, final_b, final_h, time_start_delay, time_for_effect, play_dead_priority)

		if ship ~= nil and ship:isValid() then

			if not Movements:PBHisValid({p=final_p, b=final_b, h=final_h}) then 
				ba.print("Movements SEXP Warning: move-to-orientation sexp provided with invalid final_pbh, not running rotation...\n")
				return 
			end

			local final_pbh = {
				p=math.rad(final_p), 
				b=math.rad(final_b), 
				h=math.rad(final_h)
			}

			--add entry
			--number checks are completed in function below 
			local input_tbl = {
				SR_IN_time_delay = time_start_delay,
				SR_IN_rotation_time = time_for_effect,
				SR_IN_play_dead_PR = play_dead_priority,
				SR_IN_final_pbh_target_name = nil,
				SR_IN_final_pbh_special_override = nil,
			}
			Movements:Add_Rotation(ship.Name, final_pbh, input_tbl)
		end

	end

	mn.LuaSEXPs["move-to-face-object"].Action = function(ship_to_rotate, obj_to_face_oswpt, time_start_delay, time_for_effect, play_dead_priority)

		if ship_to_rotate ~= nil and ship_to_rotate:isValid() and obj_to_face_oswpt ~= nil then

			local obj_to_face_name = Movements:Get_Name_from_Ship_or_Wpt_Obj(obj_to_face_oswpt:get())

			if obj_to_face_name ~= nil then
				--add entry
				--number checks are completed in function below 
				local input_tbl = {
					SR_IN_time_delay = time_start_delay,
					SR_IN_rotation_time = time_for_effect,
					SR_IN_play_dead_PR = play_dead_priority,
					SR_IN_final_pbh_target_name = obj_to_face_name,
					SR_IN_final_pbh_special_override = Movements.SP_FaceTarget,
				}
				Movements:Add_Rotation(ship_to_rotate.Name, {p=0,b=0,h=0}, input_tbl)
			end

		end

	end

	mn.LuaSEXPs["early-stop-move-to-orientation"].Action = function(ship)

		if ship ~= nil and ship:isValid() then
			Movements:Remove_Rotation(ship.Name, true)
		end

	end


	function Movements:Add_Waypoint_Track_Object(waypointpath_name, objecttarget_name, options_table)

		--validity checks
		if not self.is_enabled then return end
		if waypointpath_name == nil or objecttarget_name == nil then return end

		if type(options_table) ~= "table" then
			options_table = {}
		end

		local waypoint_i = options_table.WtO_IN_waypoint_i
		local offset_xyz = options_table.WtO_IN_offset_xyz
		local userelative = options_table.WtO_IN_offset_is_relative
		local track_interval = options_table.WtO_IN_track_interval
		local track_distance = options_table.WtO_IN_track_distance

		if type(offset_xyz) == "table" then
			if #offset_xyz ~= 3 then
				offset_xyz = {0,0,0}
			end
		else
			offset_xyz = {0,0,0}
		end

		if type(track_interval) ~= "number" then
			track_interval = 1.0
		end
		if track_interval < 0 then
			track_interval = 0
		end

		if type(track_distance) ~= "number" then
			track_distance = 0
		end
		if track_distance < 0 then
			track_distance = 0
		end

		if type(waypoint_i) ~= "number" then
			waypoint_i = 1
		end

		if type(waypointpath_name) ~= "string" then return end
		if type(objecttarget_name) ~= "string" then return end

		--check if object is ship or waypoint
		local object = self:Get_Ship_or_Wpt_Obj_from_Name(objecttarget_name)
		if object == nil then return end
		if not object:isValid() then return end

		local waypointpath = mn.WaypointLists[waypointpath_name]
		if waypointpath == nil then return end
		if not waypointpath:isValid() then return end

		local waypoint = waypointpath[waypoint_i]
		if waypoint == nil then return end
		if not waypoint:isValid() then return end
		local waypoint_name = self:WaypointName(waypointpath_name, waypoint_i)

		if type(userelative) ~= "boolean" then
			userelative = true
		end

		--add entry
		local entry = {
			WtO_OUT_waypoint_i = waypoint_i,
			WtO_OUT_wp_path_name = waypointpath_name,
			WtO_OUT_target_obj_name = objecttarget_name,
			WtO_OUT_offset_xyz = offset_xyz,
			WtO_OUT_offset_relative = userelative,
			WtO_OUT_track_interval = track_interval,
			WtO_OUT_time_last_check = mn.getMissionTime(),
			WtO_OUT_is_paused = false,
			WtO_OUT_track_distance = track_distance
		}

		--clear any previous entry
		self:Remove_Waypoint_Track_Object(waypoint_name)

		self.Active_Wpts_trk_Objects[waypoint_name] = entry

		--set position if needed
		local dis_wp_to_object = waypoint.Position:getDistance(object.Position)
		if dis_wp_to_object > track_distance then
			self:Set_Obj1_Pos_Relative_to_Obj2(waypoint_name, objecttarget_name, offset_xyz, userelative)
		end

		--update tracker variables
		self.Active_Wpts_trk_Objects_Sum = self.Active_Wpts_trk_Objects_Sum + 1

	end

	function Movements:Check_Waypoint_Track_Object()

		if self.Active_Wpts_trk_Objects_Sum > 0 then
			local mtime = mn.getMissionTime()
			for k_waypointname, v in pairs(self.Active_Wpts_trk_Objects) do
				--only check if interval time has surpassed
				if not v.WtO_OUT_is_paused and mtime > v.WtO_OUT_time_last_check + v.WtO_OUT_track_interval then
					v.WtO_OUT_time_last_check = mtime
					--validity checks
					local object = self:Get_Ship_or_Wpt_Obj_from_Name(v.WtO_OUT_target_obj_name)
					if object ~= nil and object:isValid() then
						local wppath = mn.WaypointLists[v.WtO_OUT_wp_path_name]
						if wppath ~= nil and wppath:isValid() then
							local wpoint = wppath[v.WtO_OUT_waypoint_i]
							if wpoint ~= nil and wpoint:isValid() then
								--then only continue if target object has moved far enough
								local dis_wp_to_object = wpoint.Position:getDistance(object.Position)
								if dis_wp_to_object > v.WtO_OUT_track_distance then
									self:Set_Obj1_Pos_Relative_to_Obj2(k_waypointname, v.WtO_OUT_target_obj_name, v.WtO_OUT_offset_xyz, v.WtO_OUT_offset_relative)
								end
							end
						end
					end
				end
			end
		end

	end

	function Movements:Pause_Waypoint_Track_Object(waypointname_key, bool_status)

		if not self.is_enabled then return end
		if waypointname_key == nil then return end

		if self.Active_Wpts_trk_Objects[waypointname_key] ~= nil then
			self.Active_Wpts_trk_Objects[waypointname_key].WtO_OUT_is_paused = bool_status
		end

	end

	function Movements:Remove_Waypoint_Track_Object(waypointname_key)

		if not self.is_enabled then return end
		if waypointname_key == nil then return end
		local entry = self.Active_Wpts_trk_Objects[waypointname_key]

		if entry ~= nil then
			self.Active_Wpts_trk_Objects[waypointname_key] = nil
			self.Active_Wpts_trk_Objects_Sum = self.Active_Wpts_trk_Objects_Sum - 1
		end

	end

	mn.LuaSEXPs["add-waypoint-track-ship"].Action = function(target_object_owspt, waypointpath, waypoint_i, offset_x, offset_y, offset_z, track_interval, track_distance, userelative)

		if waypointpath == nil or target_object_owspt == nil then return end
		if not waypointpath:isValid() then return end

		if type(offset_x) ~= "number" then
			offset_x = 0
		end
		if type(offset_y) ~= "number" then
			offset_y = 0
		end
		if type(offset_z) ~= "number" then
			offset_z = 0
		end

		track_interval = track_interval or 0
		if type(track_interval) ~= "number" then return end
		--function below takes this value in seconds not milliseconds
		track_interval = track_interval/1000

		local xyz_tbl = {offset_x, offset_y, offset_z}

		local obj_to_track_name = Movements:Get_Name_from_Ship_or_Wpt_Obj(target_object_owspt:get())

		if obj_to_track_name ~= nil then
			local input_tbl = {
				WtO_IN_waypoint_i = waypoint_i,
				WtO_IN_offset_xyz = xyz_tbl,
				WtO_IN_offset_is_relative = userelative,
				WtO_IN_track_interval = track_interval,
				WtO_IN_track_distance = track_distance
			}
			Movements:Add_Waypoint_Track_Object(waypointpath.Name, obj_to_track_name, input_tbl)
		end

	end

	mn.LuaSEXPs["pause-waypoint-track-ship"].Action = function(waypointpath, waypoint_i, pause_status)

		if waypointpath == nil then return end
		if not waypointpath:isValid() then return end

		if type(waypoint_i) ~= "number" then
			waypoint_i = 1
		end

		if type(pause_status) ~= "boolean" then
			pause_status = false
		end

		local waypoint = waypointpath[waypoint_i]
		if waypoint == nil then return end 
		if not waypoint:isValid() then return end

		local waypoint_name = Movements:WaypointName(waypointpath.Name, waypoint_i)
		Movements:Pause_Waypoint_Track_Object(waypoint_name, pause_status)

	end

	mn.LuaSEXPs["remove-waypoint-track-ship"].Action = function(waypointpath, waypoint_i)

		if waypointpath == nil then return end
		if not waypointpath:isValid() then return end

		if type(waypoint_i) ~= "number" then
			waypoint_i = 1
		end

		local waypoint = waypointpath[waypoint_i]
		if waypoint == nil then return end 
		if not waypoint:isValid() then return end

		local waypoint_name = Movements:WaypointName(waypointpath.Name, waypoint_i)
		Movements:Remove_Waypoint_Track_Object(waypoint_name)

	end


	function Movements:Time_Until_Stop(shipname)

		local stoptime = 0
		--gets ships current forward velocity and calculates time it will take to reach 0 forward velocity with max declaration
		if shipname ~= nil then
			local ship = mn.Ships[shipname]
			if ship ~= nil and ship:isValid() then
				local sphysics = ship.Physics
				if sphysics ~= nil then

					local max_speed_z = math.max(sphysics.VelocityMax[3], 1)
					local current_speed_z = math.max(sphysics:getForwardSpeed(), 0)
					local decleration_time = math.max(sphysics.ForwardDecelerationTime, 1)

					local percent_speed = current_speed_z/max_speed_z
					if percent_speed > 1 then
						percent_speed = 1
					end

					--not systematic at all, but chose to go with X percent of deceleration time
					--fortunately the ship will rotate no matter what
					stoptime = math.ceil ( decleration_time * percent_speed )
				end
			end
		end

		return stoptime

	end

	function Movements:Obstacle_In_Path(ship, wp_pause_triggered, uses_smart_stop, stop_ray_distance_min, ignore_ships_with_this_radius, time_check_interval, myship_radius, smart_stop_use_extra_check) --assumes args are valid

		if wp_pause_triggered or self:Get_Custom_Ship_PausedWaypoint(ship) then
			return true, ship
		end

		if not uses_smart_stop then 
			return false, nil
		end

		--failsafe validity checks, if either of these are -1 then we are not supposed to use smart stop
		if stop_ray_distance_min < 0 or ignore_ships_with_this_radius < 0 then
			return false, nil
		end

		local sphysics = ship.Physics
		if sphysics == nil then 
			return false, nil
		end

		if smart_stop_use_extra_check == nil then
			smart_stop_use_extra_check = true
		end

		--quick out if we are not even facing the waypoint?
		--if a ship blocks us, it would be nice to rotate to at least face the waypoint?
		--possibly not, especially with less frequent interval checks
			--b/c if we are not facing waypoint, then start turning, 10 seconds later we could have already started moving and smashed into something 

		--get how fast ship is moving and time until next check
		--how far will ship have moved in that amount of time?
		local current_speed_z = sphysics:getForwardSpeed()
		if current_speed_z < 0 then
			current_speed_z = 0 
		end
		local decleration_time = sphysics.ForwardDecelerationTime

		local extra_slow_down_multiplier = math.max(decleration_time, 3) --minimum is bit of a magic number
		local distance_covered_by_next_check = time_check_interval * current_speed_z * extra_slow_down_multiplier -- ie 10 m/s * 1.5 seconds = 15 meters covered until next check
		--if that math.max(distance * 2, ship_radius*2) is > the closest obstacle then we better hit the brakes now
		local danger_zone_distance = math.max(stop_ray_distance_min * 1.2, distance_covered_by_next_check * 1.25) --bit more magic numbers

		--has line of sight only uses vectors, so make sure we ignore ourselves when doing obstacle checks
		--lets cast the ray from the center of the ship to ensure we see everything
		local ship_pos = ship.Position
		--the end of the ray cast should extend quite a bit along the forward vector of the ship
		local ray_end_pos = ship_pos + ship.Orientation:unrotateVector(ba.createVector(0, 0, danger_zone_distance*3))

		--boolean, number getLineOfSightFirstIntersect(vector from, vector to, [table excludedObjects (expects list of objects, empty by default), boolean testForShields = false, boolean testForHull = true, number threshold = 10.0])
		--Checks whether the to-position is in line of sight from the from-position and returns the distance to the first interruption of the line of sight, disregarding specific excluded objects and objects with a radius of less then threshold.
		--Returns: true and zero if there is line of sight, false and the distance otherwise and intersecting object otherwise.
		local has_line_of_sight, closest_obstacle_distance, intersecting_obj = mn.getLineOfSightFirstIntersect(ship_pos, ray_end_pos, {ship}, false, true, ignore_ships_with_this_radius)

		local obstacle_in_way = false
		--no for 'line of sight' means there is an obstacle somewhere, so we should check where
			--obstacle is within danger zone -> obstacle in way = true
			--obstacle not within danger zone -> obstacle in way = false
		--yes for 'line of sight' means no possibility for obstacles
		if not has_line_of_sight and intersecting_obj ~= nil and intersecting_obj:isValid() then

			--if there is an obstacle
			--account for ship and target self and any obstacle radius, if specified
			if smart_stop_use_extra_check then
				--update distance with safety radius and do check
				closest_obstacle_distance = closest_obstacle_distance - (myship_radius + intersecting_obj.Radius)
			end

			if closest_obstacle_distance < 0 then 
				closest_obstacle_distance = 0 
			end

			if closest_obstacle_distance <= danger_zone_distance then
				obstacle_in_way = true
			--else --no obstacles in the way
			end

		else --if there is not a known obstacle and extra_safety_check is on, run sphere check
			--note, sphere check is more of a failsafe since it does not account for how far ship will travel before next check
			--  and it only checks ships on same team by default, 
			--  since opposing team ships would be okay with risking a collision if line of sight was clear
			if smart_stop_use_extra_check then
				local my_signature = ship:getSignature()
				local my_teamname = ship.Team.Name
				local nose_tip_position = ship_pos + ship.Orientation:unrotateVector(ba.createVector(0, 0, myship_radius))
				local mnships = mn.Ships
				local tmatch = self.Extra_SmartStop_Uses_Team_Match
				for k_sname, v_sinfo in pairs(self.Active_Big_Ships) do
					local l_ship = mnships[k_sname]
					local l_team = v_sinfo.activebig_team
					if my_signature ~= v_sinfo.activebig_signature then
						if not tmatch or (tmatch and (l_team == my_teamname or l_team == "Civilian")) then
							if l_ship ~= nil and l_ship:isValid() then
								if self:Has_Overlap(nose_tip_position, myship_radius, l_ship.Position, l_ship.Radius, true) then
									intersecting_obj = l_ship
									obstacle_in_way = true
									break
								end
							end
						end
					end
				end
			end

		end

		return obstacle_in_way, intersecting_obj

	end

	function Movements:Add_Ship_Track_Waypoint(shipname, waypoint_path_name, options_table) --input_final_pbh should be {p=0,b=0,h=0} in radians

		--validity checks
		if not self.is_enabled then return end
		if shipname == nil then return end
		if not mn.Ships[shipname]:isValid() then return end
		if waypoint_path_name == nil then return end
		if mn.WaypointLists[waypoint_path_name] == nil then return end

		if type(options_table) ~= "table" then
			options_table = {}
		end

		local priority = options_table.StW_IN_track_priority
		local track_interval = options_table.StW_IN_track_interval
		local track_distance = options_table.StW_IN_track_distance
		local input_final_pbh = options_table.StW_IN_final_pbh
		local final_pbh_target_name = options_table.StW_IN_final_pbh_target_name
		local special_override_final_pbh = options_table.StW_IN_final_pbh_special_override
		local continuous_pbh_check = options_table.StW_IN_continuous_pbh_check
		local play_dead_PR = options_table.StW_IN_play_dead_PR
		local uses_smart_stop = options_table.StW_IN_uses_smart_stop
		local smart_stop_ray_distance_min = options_table.StW_IN_smart_stop_ray_distance_min
		local smart_stop_ignore_radius = options_table.StW_IN_smart_stop_ignore_radius
		local smart_stop_use_extra_check = options_table.StW_IN_smart_stop_use_extra_check
		local waypoint_pause_triggered = options_table.StW_IN_waypoint_pause_triggered

		if type(continuous_pbh_check) ~= "boolean" then
			continuous_pbh_check = true
		end

		--priority checks
		if type(priority) ~= "number" then
			priority = 100
		end
		if priority < 0 then
			priority = 0
		end

		--set play_dead_PR priority, default is disabled
		--recall this one CAN be negative and if so it disables the play dead persistent
		if type(play_dead_PR) ~= "number" then
			play_dead_PR = -1
		end
		--cap if too high
		if play_dead_PR > 200 then
			play_dead_PR = 200
		end
		--no floor since it can be negative

		local mtime = mn.getMissionTime()

		--default for track time interval
		if type(track_interval) ~= "number" then
			track_interval = 1.500
		end
		if track_interval < 0 then
			track_interval = 0
		end

		local ship = mn.Ships[shipname]

		local waypoint_path = mn.WaypointLists[waypoint_path_name]

		if waypoint_path[1] == nil then return end

		if not waypoint_path[1]:isValid() then return end

		local num_waypoints = #waypoint_path --remember only good for one frame, so don't add extra waypoints to this path

		local last_wp = waypoint_path[num_waypoints]
		local first_wp = waypoint_path[1]
		if last_wp == nil or first_wp == nil then return end

		if not last_wp:isValid() or not first_wp:isValid() then return end

		--set known waypoint location (use this to counter act ship over-shooting waypoint)
		local previous_waypoint_location = last_wp.Position

		local ship_radius = ship.Radius
		if ship_radius < 1 then ship_radius = 1 end

		--set default track distance to ship radius
		--negative value also uses default value
		if type(track_distance) ~= "number" then
			track_distance = -1
		end
		if track_distance < 0 then
			track_distance = ship_radius
			--final safety check 
			if track_distance <= 0 then
				track_distance = 100
			end
		end

		--set final target pbh if available
		local final_pbh = {} --this is default, only change if the input had 3 number values
		if self:PBHisValid(input_final_pbh) then
			for _,v in ipairs({"p", "b", "h"}) do
				final_pbh[v] = input_final_pbh[v]
			end
		end

		--also set final target ship (will only work if final pbh set)
		if type(final_pbh_target_name) ~= "string" then
			final_pbh_target_name = nil
		end

		--check if the ship will try to stop if it is about to hit something
		--if using smart_stop then get radius of the ship *2 (-1 is default and disables this)
		--checks every track_interval
		if uses_smart_stop == nil then
			uses_smart_stop = false
		end 

		if uses_smart_stop then
			--if obstacle is within this distance it will trigger a stop
			if type(smart_stop_ray_distance_min) ~= "number" then
				smart_stop_ray_distance_min = -1 -- -1 triggers default
			end
			if smart_stop_ray_distance_min < 0 then
				smart_stop_ray_distance_min = ship_radius * 2 --default value of ship diameter
			--else --keep as is
			end

			--any obstacles this radius or smaller will not be registered as obstacles
			if type(smart_stop_ignore_radius) ~= "number" then
				smart_stop_ignore_radius = -1 -- -1 triggers default
			end
			if smart_stop_ignore_radius < 0 then 
				smart_stop_ignore_radius = self.Default_ShipRadius_is_Obstacle --default value of 25
			end

			--use extra safety buffer, default is yes
			if smart_stop_use_extra_check == nil then
				smart_stop_use_extra_check = true
			end
		else
			smart_stop_ray_distance_min = -1
			smart_stop_ignore_radius = -1
			smart_stop_use_extra_check = false
		end

		if waypoint_pause_triggered == nil then 
			waypoint_pause_triggered = false
		end

		--add entry using ship name as key and update total number variable
		local entry = {
			StW_OUT_shipname = shipname,
			StW_OUT_wp_path_name = waypoint_path_name,
			StW_OUT_num_waypoints = num_waypoints,
			StW_OUT_priority = priority,
			StW_OUT_play_dead_PR = play_dead_PR,
			StW_OUT_track_interval = track_interval,
			StW_OUT_time_last_check = mtime,
			StW_OUT_previous_wp_location = previous_waypoint_location,
			StW_OUT_track_distance = track_distance,
			StW_OUT_is_running_wp_once = true,
			StW_OUT_final_pbh_table = final_pbh, --remember needs to be in radians
			StW_OUT_final_pbh_target_name = final_pbh_target_name,
			StW_OUT_final_pbh_override = special_override_final_pbh or -1,
			StW_OUT_continuous_pbh_check = continuous_pbh_check,
			StW_OUT_ship_radius = ship_radius,
			StW_OUT_wp_pause_triggered = waypoint_pause_triggered,
			StW_OUT_uses_smart_stop = uses_smart_stop,
			StW_OUT_smart_stop_ray_min = smart_stop_ray_distance_min, --only used if using smart stop
			StW_OUT_smart_stop_triggered = false, --only used if using smart stop
			StW_OUT_smart_stop_blocking_obj_sig = -1,
			StW_OUT_smart_stop_ignore_radius = smart_stop_ignore_radius, --only used if using smart stop,
			StW_OUT_smart_stop_use_extra_check = smart_stop_use_extra_check
		}

		--remove any other tracking of waypoints for this ship
		self:Remove_Ship_Track_Waypoint(shipname)

		--only give it the order if the ship is far enough away from the first waypoint
		--if the distance is not far enough away then it will keep checking on the ship track waypoint function
		--check to make sure there is not an obstacle in the path, too
		local dis_to_wp1 = first_wp.Position:getDistance(ship.Position)
		if dis_to_wp1 > track_distance then
			--if ship has space to actually run waypoints
			local run_order = true
			local obstacle_in_path, blocking_obj = self:Obstacle_In_Path(ship, waypoint_pause_triggered, uses_smart_stop, entry.StW_OUT_smart_stop_ray_min, entry.StW_OUT_smart_stop_ignore_radius, entry.StW_OUT_track_interval, entry.StW_OUT_ship_radius, entry.StW_OUT_smart_stop_use_extra_check)
			if obstacle_in_path and blocking_obj ~= nil then
				run_order = false
				entry.StW_OUT_smart_stop_triggered = true
				entry.StW_OUT_smart_stop_blocking_obj_sig = blocking_obj:getSignature()
				--if the obstacle ship is the target ship then the per simulation frame checks will take care of that
			end
			--give initial waypoint order if no obstacles
			if run_order then
				ship:giveOrder(ORDER_WAYPOINTS_ONCE, first_wp, nil, priority/100)
			end
		else -- if distance is too small then the ship is considered to have done its waypoint path instantly (On Waypoints Done)
			entry.StW_OUT_is_running_wp_once = false
		end

		self.Active_Ships_trk_Wpts_Sum = self.Active_Ships_trk_Wpts_Sum + 1

		self.Active_Ships_trk_Wpts[shipname] = entry

	end

	function Movements:Reset_Track_Waypoint_Time(shipname)

		local wp_entry = self.Active_Ships_trk_Wpts[shipname]
		if wp_entry ~= nil then
			wp_entry.StW_OUT_time_last_check = -1 --force a recheck next frame instead of waiting for interval
		end

	end

	function Movements:Clear_Custom_Ship_PausedWaypoint()

		self.Ships_Waypoints_Paused1_List = {}
		self.Ships_Waypoints_Paused1_On = false

		self.Ships_Waypoints_Paused2_List = {}
		self.Ships_Waypoints_Paused2_On = false

	end

	function Movements:Get_Custom_Ship_PausedWaypoint(ship, do_validity)

		if self.Ships_Waypoints_Paused1_On or self.Ships_Waypoints_Paused2_On then
			local shipname
			if do_validity then
				if ship ~= nil and ship:isValid() then
					shipname = ship.Name
				end
			else
				shipname = ship.Name
			end
			if shipname ~= nil and (self.Ships_Waypoints_Paused1_List[shipname] or self.Ships_Waypoints_Paused2_List[shipname]) then
				return true
			end
		end

		return false

	end

	function Movements:Update_Custom_Ship_PausedWaypoint(shipname, status, i_list, run_rotation_remove)

		--adds to list of paused overrides, 
		--  if on either list then the ship will always be in pause mode
		--even if the ship entry in the waypoint_track list is not in pause mode

		if shipname ~= nil then

			self:Reset_Track_Waypoint_Time(shipname)

			if run_rotation_remove then
				self:Remove_Rotation(shipname)
			end

			if i_list == 1 then
				self.Ships_Waypoints_Paused1_List[shipname] = status
				self.Ships_Waypoints_Paused1_On = true
			elseif i_list == 2 then
				self.Ships_Waypoints_Paused2_List[shipname] = status
				self.Ships_Waypoints_Paused2_On = true
			else
				self.Ships_Waypoints_Paused1_List[shipname] = status
				self.Ships_Waypoints_Paused1_On = true
				self.Ships_Waypoints_Paused2_List[shipname] = status
				self.Ships_Waypoints_Paused2_On = true
			end
		end

	end

	function Movements:Remove_Ship_Track_Waypoint(shipname_key)

		if not self.is_enabled then return end
		if shipname_key == nil then return end
		local entry = self.Active_Ships_trk_Wpts[shipname_key]

		if entry ~= nil then

			local ship = mn.Ships[shipname_key]
			--remove any play dead order just in case they did not get removed when rotation done
			if entry.StW_OUT_play_dead_PR >= 0 then 
				self:RemoveGoal_Correctly(ship, entry.StW_OUT_play_dead_PR, "ai-play-dead-persistent")
			end

			--remove any waypoints once order
			self:RemoveGoal_Correctly(ship, entry.StW_OUT_priority, "ai-waypoints-once", entry.StW_OUT_wp_path_name)

			--remove from list and update variables
			self.Active_Ships_trk_Wpts[shipname_key] = nil
			self.Active_Ships_trk_Wpts_Sum = self.Active_Ships_trk_Wpts_Sum - 1

		end

	end

	function Movements:On_Waypoints_Done(shipname, done_wp_path_name) --has to be only called with 'On Waypoints Done'

		--change waypoint status and save location of last waypoint

		--validity checks
		if not self.is_enabled then return end
		if shipname == nil or done_wp_path_name == nil then return end 
		local entry = self.Active_Ships_trk_Wpts[shipname]
		if entry == nil then return end

		--only continue if the completed waypoint was the one specified in tracker goal
		if entry.StW_OUT_wp_path_name ~= done_wp_path_name then return end

		--change status, this (On Waypoints Done) is the only time this gets set to false (besides special instant waypoint finish on initiation)
		entry.StW_OUT_is_running_wp_once = false

		--save last known waypoint location
		--using last known location of last waypoint helps mitigate effects of the ship over-shooting the final waypoint
		if entry.StW_OUT_previous_wp_location ~= nil and entry.StW_OUT_wp_path_name ~= nil then
			local wppath = mn.WaypointLists[entry.StW_OUT_wp_path_name]
			if wppath ~= nil and wppath:isValid() and entry.StW_OUT_num_waypoints ~= nil then
				local lastwp = wppath[entry.StW_OUT_num_waypoints]
				if lastwp ~= nil and lastwp:isValid() and entry.StW_OUT_previous_wp_location ~= nil then
					entry.StW_OUT_previous_wp_location = lastwp.Position
				end
			end
		end

		--if there is a target orientation and no active rotations then add a run rotation order
			--recall that continuous checking of target pbh is done in ':Check_Ship_trk_Wpt()'
		if self.Active_Rotations[shipname] == nil and self:PBHisValid(entry.StW_OUT_final_pbh_table) then

			--early out if target ship is specified but not in mission
			--this is checked in rotation too, but might as well have earlier check here for slight optimization
			if entry.StW_OUT_final_pbh_target_name ~= nil then
				if mn.Ships[entry.StW_OUT_final_pbh_target_name] == nil then
					return 
				end
			end

			--add rotation
			--  recall the ship just finished a waypoint..
			--  need time delay so the craft is not moving forward anymore
			local input_tbl = {
				SR_IN_time_delay = self:Time_Until_Stop(shipname),
				SR_IN_rotation_time = -1,
				SR_IN_play_dead_PR = entry.StW_OUT_play_dead_PR,
				SR_IN_final_pbh_target_name = entry.StW_OUT_final_pbh_target_name,
				SR_IN_final_pbh_special_override = entry.StW_OUT_final_pbh_override,
				SR_IN_requires_engines = true
			}

			--recall add rotation will create the final orientation once timer is triggered, 
			--so just add in the base pbh table as the input
			self:Add_Rotation(shipname, entry.StW_OUT_final_pbh_table, input_tbl)

		--if not valid final orientation then don't run rotate-to-orientation
		end

	end

	function Movements:Obstacle_Is_FinalTarget(final_target_name, current_obstacle_obj)

		local answer = false

		if final_target_name ~= "" and final_target_name ~= nil then
			local final_target = mn.Ships[final_target_name]
			if final_target ~= nil and final_target:isValid() and current_obstacle_obj ~= nil and current_obstacle_obj:isValid() then
				--does final target == current obstacle?
				if current_obstacle_obj:getSignature() == final_target:getSignature() then
					answer = true
				end
			end
		end

		return answer

	end

	function Movements:Check_Ship_trk_Wpt() --checked every simulation frame

		if self.Active_Ships_trk_Wpts_Sum > 0 then
			local mtime = mn.getMissionTime()

			for _, v in pairs(self.Active_Ships_trk_Wpts) do

				--only check if the tracker time has elapsed
				if mtime > v.StW_OUT_time_last_check + v.StW_OUT_track_interval then

					v.StW_OUT_time_last_check = mtime

					local wpname = v.StW_OUT_wp_path_name or ""
					local wppath = mn.WaypointLists[wpname]
					local ship = mn.Ships[v.StW_OUT_shipname]

					if wppath ~= nil and wppath:isValid() and ship ~= nil and ship:isValid() then
						local lastwp = wppath[v.StW_OUT_num_waypoints]
						if lastwp ~= nil and lastwp:isValid() then
							--check if ship is currently following waypoint order or not
							--  if following then check if we need to do smart stop
							--  if just chilling then check what ship needs to do now
							if v.StW_OUT_is_running_wp_once then
								--cases
								--yes obstacle found
									--ship currently moving -> stop
									--ship not moving -> do nothing
								--no obstacles found
									--ship currently moving -> do nothing
									--ship not moving -> go and start moving again

								local ship_currently_moving = not v.StW_OUT_smart_stop_triggered
								local obstacle_in_path, intersecting_obj = self:Obstacle_In_Path(ship, v.StW_OUT_wp_pause_triggered, v.StW_OUT_uses_smart_stop, v.StW_OUT_smart_stop_ray_min, v.StW_OUT_smart_stop_ignore_radius, v.StW_OUT_track_interval, v.StW_OUT_ship_radius, v.StW_OUT_smart_stop_use_extra_check)

								if obstacle_in_path and intersecting_obj ~= nil then  --found obstacle
									if ship_currently_moving then
										--stop ship
										self:RemoveGoal_Correctly(ship, v.StW_OUT_priority, "ai-waypoints-once", v.StW_OUT_wp_path_name)
										v.StW_OUT_smart_stop_triggered = true
										v.StW_OUT_smart_stop_blocking_obj_sig = intersecting_obj:getSignature()
									else --ship not moving
										--what if the ship stopped b/c it got too close to it's final target? (ie final target is the obstacle)
										--if that happens then this ship will never rotate to match target b/c it will never complete its waypoints
										--so, if the ship has been told to stop moving, then check if it's within distance to its target, then fake a waypoints complete
										local obstacle_is_target = false

										--if the ship is already within the wiggle room for a waypoint track then go ahead as a shortcut
										local dis_wp = lastwp.Position:getDistance(ship.Position)
										if dis_wp <= v.StW_OUT_track_distance then
											obstacle_is_target = true
										else --shortcut didn't work so check if obstacle is target ship
											obstacle_is_target = self:Obstacle_Is_FinalTarget(v.StW_OUT_final_pbh_target_name, intersecting_obj)
										end

										--if close enough to final waypoint or obstacle is target then consider "On Waypoints Done"
										if obstacle_is_target then
											self:On_Waypoints_Done(v.StW_OUT_shipname, v.StW_OUT_wp_path_name)
										end

									end

								else --no obstacles
									if not ship_currently_moving then
										--start moving again
										local wp_list = mn.WaypointLists[v.StW_OUT_wp_path_name]
										if wp_list ~= nil and wp_list:isValid() then
											ship:giveOrder(ORDER_WAYPOINTS_ONCE, wp_list[1], nil, v.StW_OUT_priority/100)
										end
										v.StW_OUT_smart_stop_triggered = false
										v.StW_OUT_smart_stop_blocking_obj_sig = -1
									--else --ship is moving, and no obstacles so keep on doing what we are already doing
									end

								end


							else --not running waypoint order (waypoints have been completed, waiting to see if need to update)

								--cases 
									--waypoint has moved far enough away to trigger refreshed path order
										--using smart stop and there is an obstacle
											--obstacle is target ship
												-->do not give refreshed order yet and do run about idle rotations
											--obstacle is not target ship 
												-->do not give refreshed order yet also do not worry about idle rotations
										--using smart stop and no obstacle or just not using smart stop
									--waypoint still within wiggle room for no new order
										--using smart stop and there is an obstacle
											--> does not matter, just rotating, and waypoints have already been completed so run idle rotation
										--using smart stop and no obstacle or just not using smart stop
											--> does not matter, just rotating, and waypoints have already been completed so run idle rotation

								--get distance between waypoint's last location and it's current new location (it might have moved)
								local dis_wp_previous_to_wp_now = lastwp.Position:getDistance(v.StW_OUT_previous_wp_location)

								--see if distance between last waypoint path and ship is too far
								--  using last known location of last waypoint helps mitigate effects of the ship overshooting the final waypoint
								--  add goal and set to tracking

								local check_run_pbh = false

								if dis_wp_previous_to_wp_now > v.StW_OUT_track_distance then
									--if waypoint has moved too far then we need to stop what we are doing and follow it
									--recall the parent conditionals check if the waypoints order is already running

									local obstacle_in_path, intersecting_obj = self:Obstacle_In_Path(ship, v.StW_OUT_wp_pause_triggered, v.StW_OUT_uses_smart_stop, v.StW_OUT_smart_stop_ray_min, v.StW_OUT_smart_stop_ignore_radius, v.StW_OUT_track_interval, v.StW_OUT_ship_radius, v.StW_OUT_smart_stop_use_extra_check)

									if obstacle_in_path and intersecting_obj ~= nil then
										--might have case where waypoint is far enough away to trigger new path order, but obstacle is the target ship
										--so since stopped at target might as well rotate to target orientation
										--if not final target though and just regular obstacle then stay put and do not resume waypoints
										if self:Obstacle_Is_FinalTarget(v.StW_OUT_final_pbh_target_name, intersecting_obj) then
											check_run_pbh = true
										--else --continue to do nothing/stay still
										end

									else --not using smart stop, or using smart stop and obstacle not in the way
										--run remove rotation just to be on the safe side
										self:Remove_Rotation(v.StW_OUT_shipname)

										--start waypoints once
										local wp_list = mn.WaypointLists[v.StW_OUT_wp_path_name]
										if wp_list ~= nil and wp_list:isValid() then
											ship:giveOrder(ORDER_WAYPOINTS_ONCE, wp_list[1], nil, v.StW_OUT_priority/100)
										end
										v.StW_OUT_is_running_wp_once = true
									end

								else
									--recall the obstacle check used above internal has the 'check custom paused' check
									if not self:Get_Custom_Ship_PausedWaypoint(ship) then  
										check_run_pbh = true
									end

								end

								if check_run_pbh then

									--if the ship does not have resume the waypoint order then
									--check if we are using the option to always match orientations
									--if so, then run the rotate order if the previous orientation is substantially different and not actively rotating
									--recall initial rotating to target pbh was already called when waypoint path was completed on :On_Waypoints_Done()
									if v.StW_OUT_continuous_pbh_check and self.Active_Rotations[v.StW_OUT_shipname] == nil then

										--only using 'get final PBH' to check if current and final orientations are equal or not
										--recall that 'get final PBH' checks for validity 
										--PBH_table_final in {p=,b=,h=}
										local fo = self:GetFinal_PBH(ship, v.StW_OUT_final_pbh_table, v.StW_OUT_final_pbh_target_name, v.StW_OUT_final_pbh_override) 

										if fo ~= nil and not self:All_PBH_Values_Within_Threshold(ship.Orientation, fo, 0.02) then --0.02 radians = 1.15 degrees
											--orientations are not equal, so add rotation order
											local input_tbl = {
												SR_IN_time_delay = self:Time_Until_Stop(v.StW_OUT_shipname) * 1.5, --let On Waypoints Done rotation trigger first
												SR_IN_rotation_time = -1, --for default rotate time
												SR_IN_play_dead_PR = v.StW_OUT_play_dead_PR,
												SR_IN_final_pbh_target_name = v.StW_OUT_final_pbh_target_name,
												SR_IN_final_pbh_special_override = v.StW_OUT_final_pbh_override,
												SR_IN_requires_engines = true
											}

											--recall add rotation will create the final orientation once timer is triggered, 
											--so just add in the base pbh table as the input
											self:Add_Rotation(v.StW_OUT_shipname, v.StW_OUT_final_pbh_table, input_tbl)

										end

									end

								end

							end
						end
					end

				end

			end

		end

	end

	function Movements:Get_Current_Obstacle_Signature(shipname) --returns blocking signature if there is a blocker, otherwise -1 if ship tracking not valid or no obstacle or otherwise

		-- narrow but useful function to get the obstacle of a given ship if the ship is tracking a waypoint and has stopped due to 'smart stop'

		-- check if this ship is even using tracking waypoints
		if self.Active_Ships_trk_Wpts == nil then return -1 end
		local ship_entry = self.Active_Ships_trk_Wpts[shipname]
		if ship_entry== nil then return -1 end

		-- failsafe if stop not triggered
		if not ship_entry.StW_OUT_smart_stop_triggered then return -1 end

		-- return the signature 
		return ship_entry.StW_OUT_smart_stop_blocking_obj_sig

	end

	function Movements:Set_Waypoint_Pause_Trigger(shipname, trigger_boolean, run_rotation_remove)

		--setting to true will pause movements along a waypoint, 
		--  regardless of whether using smart stop or not
		--setting to false will just let the waypoint logic go back to normal, 
		--  assuming the ship is not also on the custom pause lists

		if not self.is_enabled then return end
		if shipname == nil then return end
		local entry = self.Active_Ships_trk_Wpts[shipname]

		if entry ~= nil then
			entry.StW_OUT_wp_pause_triggered = trigger_boolean
			self:Reset_Track_Waypoint_Time(shipname)
			if run_rotation_remove then
				self:Remove_Rotation(shipname)
			end
		end

	end

	mn.LuaSEXPs["pause-ai-goal-track-waypoint"].Action = function(ship, trigger_bool, stop_any_rotations)

		if ship ~= nil and ship:isValid() then
			Movements:Set_Waypoint_Pause_Trigger(ship.Name, trigger_bool, stop_any_rotations)
		end

	end

	mn.LuaSEXPs["add-ai-goal-track-waypoint"].Action = function(ship, waypointpath, priority, track_interval, track_distance, use_smart_stop, smart_stop_ray_distance_min, smart_stop_ignore_radius, smart_stop_use_extra_check)

		--recall this doesn't take into account target ship, so nothing about the orientation, continuous_pbh_check, or play_dead_PR is set here. 
		--this should only be used for waypoints not related to ships, if more is needed use the actual function

		if ship ~= nil and ship:isValid() then

			--add entry
			--number checks are completed in function below 
			--track_interval in sexp is in milliseconds so convert it to seconds 
			track_interval = track_interval or 1500
			if type(track_interval) ~= "number" then return end
			track_interval = track_interval/1000

			--function takes a waypoint_path_name as string but this sexp takes the entire waypoint_path object
			local waypointpath_name = waypointpath.Name

			--these defaults are set in following function
			--smart_stop_ray_distance_min, smart_stop_ignore_radius, smart_stop_use_extra_check

			local input_tbl = {
				StW_IN_track_priority = priority,
				StW_IN_track_interval = track_interval,
				StW_IN_track_distance = track_distance,
				StW_IN_final_pbh = nil,
				StW_IN_final_pbh_target_name = nil,
				StW_IN_final_pbh_special_override = -1,
				StW_IN_continuous_pbh_check = nil,
				StW_IN_play_dead_PR = nil,
				StW_IN_uses_smart_stop = use_smart_stop,
				StW_IN_smart_stop_ray_distance_min = smart_stop_ray_distance_min,
				StW_IN_smart_stop_ignore_radius = smart_stop_ignore_radius,
				StW_IN_smart_stop_use_extra_check = smart_stop_use_extra_check,
				StW_IN_waypoint_pause_triggered = false
			}

			Movements:Add_Ship_Track_Waypoint(ship.Name, waypointpath_name, input_tbl)
			--^^recall target is not used in this sexp, so it won't be used

		end

	end

	mn.LuaSEXPs["remove-ai-goal-track-waypoint"].Action = function(ship)

		if ship ~= nil and ship:isValid() then
			--number checks are completed in function below 
			Movements:Remove_Ship_Track_Waypoint(ship.Name)
		end

	end


	function Movements:Set_Idle_Tracking_PBH(shipname, pitch, bank, heading, targetobject_name, continuous_pbh_check) --needs to be in radians

		--use this to update or set the idle orientation of a ship tracking a waypoint
		--remember needs to be in radians
		if not self.is_enabled then return end
		if shipname == nil then return end
		local entry = self.Active_Ships_trk_Wpts[shipname]
		if entry == nil then return end

		if type(continuous_pbh_check) ~= "boolean" then continuous_pbh_check = true end

		if type(pitch) == "number" and type(bank) == "number" and type(heading) == "number" then
			--update pbh
			local input_pbh = {p=pitch, b=bank, h=heading}
			for k,v in pairs(input_pbh) do
				entry.StW_OUT_final_pbh_table[k] = v
			end

			--update continuous_pbh_check
			entry.StW_OUT_continuous_pbh_check = continuous_pbh_check

			--update target object
			if type(targetobject_name) == "string" then
				entry.StW_OUT_final_pbh_target_name = targetobject_name
			else
				entry.StW_OUT_final_pbh_target_name = nil
			end
		end

	end

	function Movements:Unset_Idle_Tracking_PBH(shipname_key)

		--use this to remove the idle tracking function for a ship that is tracking a waypoint path
		if not self.is_enabled then return end
		if shipname_key == nil then return end
		if type(shipname_key) ~= "string" then return end
		local entry = self.Active_Ships_trk_Wpts[shipname_key]
		if entry == nil then return end

		entry.StW_OUT_final_pbh_table = {}
		entry.StW_OUT_final_pbh_target_name = nil
		entry.StW_OUT_continuous_pbh_check = false
		entry.StW_OUT_final_pbh_override = -1

	end

	mn.LuaSEXPs["set-idle-track-orientation"].Action = function(ship, pitch, bank, heading, usetargetship, input_targetship, continuous_pbh_check)

		if ship ~= nil and ship:isValid() then
			--if target ship is specified only run if it's in mission
			if usetargetship == nil then
				usetargetship = false
			end
			local targetobject_name
			if usetargetship then --if false then it's nil
				if input_targetship == nil then return end
				if not input_targetship:isValid() then return end
				--^those function termination lines prevent set idle tracking from running with a nil target ship, because the target is not really supposed to be nil (it just hasn't arrived yet or is dod) 
				if input_targetship:isValid() then
					targetobject_name = input_targetship.Name
				end
			end

			if not Movements:PBHisValid({p=pitch, b=bank, h=heading}) then 
				ba.print("Movements SEXP Warning: set-idle-track-orientation sexp provided with invalid pitch, bank, or heading values, not setting orientation...\n")
				return 
			end

			Movements:Set_Idle_Tracking_PBH(ship.Name, math.rad(pitch), math.rad(bank), math.rad(heading), targetobject_name, continuous_pbh_check)
		end

	end

	mn.LuaSEXPs["unset-idle-track-orientation"].Action = function(ship)

		if ship ~= nil and ship:isValid() then
			Movements:Unset_Idle_Tracking_PBH(ship.Name)
		end

	end


	function Movements:Add_Ship_Track_Ship(ship_to_order_name, ship_to_track_name, waypointpath_name, options_table) --pbh should be in radians
		--higher level function that runs all the above functions
		--recall this has access to some other arguments that the individual lower level sexps do not such as use relative, continuous_pbh_check, and play_dead_PR

		if type(options_table) ~= "table" then
			options_table = {}
		end

		local waypoint_i = options_table.StS_IN_waypoint_i
		local priority = options_table.StS_IN_track_priority
		local offset = options_table.StS_IN_track_offset
		local pbh = options_table.StS_IN_final_pbh
		local userelative = options_table.StS_IN_use_relative_pbh
		local continuous_pbh_check = options_table.StS_IN_continuous_pbh_check
		local play_dead_PR = options_table.StS_IN_play_dead_PR
		local use_smart_stop = options_table.StS_IN_use_smart_stop
		local pbh_special_override = options_table.StW_IN_final_pbh_special_override

		--set defaults 
		if not self.is_enabled then return end
		if type(ship_to_order_name) ~= "string" then return end
		if type(ship_to_track_name) ~= "string" then return end
		if type(waypointpath_name) ~= "string" then return end
		if type(waypoint_i) ~= "number" then
			waypoint_i = 1
		end
		if waypoint_i < 0 then
			waypoint_i = 1
		end
		local track_interval = 1.0 --default
		local track_distance = -1	---1 for radius default of ship radius

		local offset_xyz

		if type(offset) == "table" and type(offset[1]) == "number" and type(offset[2]) == "number" and type(offset[3]) == "number" then
			offset_xyz = offset
		else
			local default_offset = ( self:Get_Ship_Radius(ship_to_order_name, true, 100) + self:Get_Ship_Radius(ship_to_track_name, true, 100) ) * 1.5
			offset_xyz = {default_offset, default_offset, default_offset}
		end

		local idle_pbh = {} --if blank then does not rotate at end
		if self:PBHisValid(pbh) then
			for _,v in ipairs({"p", "b", "h"}) do
				idle_pbh[v] = pbh[v]
			end
		end

		--run waypoint track ship 
		local wp_trk_obj_input_tbl = {
			WtO_IN_waypoint_i = waypoint_i,
			WtO_IN_offset_xyz = offset_xyz,
			WtO_IN_offset_is_relative = userelative,
			WtO_IN_track_interval = track_interval,
			WtO_IN_track_distance = track_distance
		}
		self:Add_Waypoint_Track_Object(waypointpath_name, ship_to_track_name, wp_trk_obj_input_tbl)

		--run ship track waypoint, include setting 
		local track_distance_ship = -1 --so it uses default ship radius
		--other defaults and validity checks are performed in function below
		local ship_trk_wp_input_tbl = {
			StW_IN_track_priority = priority,
			StW_IN_track_interval = track_interval,
			StW_IN_track_distance = track_distance_ship,
			StW_IN_final_pbh = idle_pbh,
			StW_IN_final_pbh_target_name = ship_to_track_name,
			StW_IN_final_pbh_special_override = pbh_special_override,
			StW_IN_continuous_pbh_check = continuous_pbh_check,
			StW_IN_play_dead_PR = play_dead_PR,
			StW_IN_uses_smart_stop = use_smart_stop,
			StW_IN_smart_stop_ray_distance_min = nil,
			StW_IN_smart_stop_ignore_radius = nil,
			StW_IN_smart_stop_use_extra_check = nil,
			StW_IN_waypoint_pause_triggered = false
		}

		self:Add_Ship_Track_Waypoint(ship_to_order_name, waypointpath_name, ship_trk_wp_input_tbl)

	end

	function Movements:Remove_Ship_Track_Ship(shipname_to_remove_order, waypointpath_name, waypoint_i)

		--validity checks
		if not self.is_enabled then return end
		if type(shipname_to_remove_order) ~= "string" then return end
		if type(waypointpath_name) ~= "string" then return end
		if type(waypoint_i) ~= "number" then
			waypoint_i = 1
		end

		--first stop waypoint tracking ship
		local waypoint_name = self:WaypointName(waypointpath_name, waypoint_i)
		self:Remove_Waypoint_Track_Object(waypoint_name)

		--then remove ship_order tracking of that waypoint 
		self:Remove_Ship_Track_Waypoint(shipname_to_remove_order)

	end

	mn.LuaSEXPs["add-ai-goal-track-ship"].Action = function(ship_to_order, ship_to_track, waypointpath, priority, off_x, off_y, off_z, pbh_p, pbh_b, pbh_h, userelative, continuous_pbh_check, play_dead_PR, use_smart_stop)

		if ship_to_order == nil or ship_to_track == nil or waypointpath == nil then return end
		if not ship_to_order:isValid() or not ship_to_track:isValid() or not waypointpath:isValid() then return end

		local ship_to_order_name = ship_to_order.Name
		local ship_to_track_name = ship_to_track.Name
		local waypointpath_name = waypointpath.Name

		if type(pbh_p) ~= "number" then
			pbh_p = 0
		end
		if type(pbh_b) ~= "number" then
			pbh_b = 0
		end
		if type(pbh_h) ~= "number" then
			pbh_h = 0
		end

		pbh_p = math.rad(pbh_p)
		pbh_b = math.rad(pbh_b)
		pbh_h = math.rad(pbh_h)

		local waypoint_i = 1

		local offset = {off_x, off_y, off_z}
		local pbh = {p=pbh_p, b=pbh_b, h=pbh_h}

		local input_tbl = {
			StS_IN_waypoint_i = waypoint_i,
			StS_IN_track_priority = priority,
			StS_IN_track_offset = offset,
			StS_IN_final_pbh = pbh,
			StS_IN_use_relative_pbh = userelative,
			StS_IN_continuous_pbh_check = continuous_pbh_check,
			StS_IN_play_dead_PR = play_dead_PR,
			StS_IN_use_smart_stop = use_smart_stop
		}

		Movements:Add_Ship_Track_Ship(ship_to_order_name, ship_to_track_name, waypointpath_name, input_tbl)

	end

	mn.LuaSEXPs["remove-ai-goal-track-ship"].Action = function(ship_to_remove_order, waypointpath, waypoint_i)

		if ship_to_remove_order == nil or waypointpath == nil then return end
		if not ship_to_remove_order:isValid() or not waypointpath:isValid() then return end

		local ship_to_remove_order_name = ship_to_remove_order.Name
		--local ship_to_stop_track_name = ship_to_stop_track.Name
		local waypointpath_name = waypointpath.Name		

		Movements:Remove_Ship_Track_Ship(ship_to_remove_order_name, waypointpath_name, waypoint_i)

	end


	function Movements:Ship_DoD_Remove(ship)

		if ship == nil then return end
		if not ship:isValid() then return end

		local shipname = ship.Name
		--goes through all movements lists and removes entries of that ship where needed to save memory

		--stop any rotations
		self:Remove_Rotation(shipname)

		--go through waypoints track ship and search for this ship name 
		if self.Active_Wpts_trk_Objects_Sum > 0 then
			for k_waypointname, v in pairs(self.Active_Wpts_trk_Objects) do
				if v.WtO_OUT_target_obj_name == shipname then
					self:Remove_Waypoint_Track_Object(k_waypointname)
				end
			end
		end

		--remove any idle orientations that are using this ship has a relative orientation base
		if self.Active_Ships_trk_Wpts_Sum > 0 then
			for _, v in pairs(self.Active_Ships_trk_Wpts) do
				if v.StW_OUT_final_pbh_target_name == shipname then
					v.StW_OUT_final_pbh_table = {}
					v.StW_OUT_final_pbh_target_name = nil
					v.StW_OUT_final_pbh_override = -1
				end
			end
		end		

		--remove any ship tracking waypoints 
		self:Remove_Ship_Track_Waypoint(shipname)

		--remove tracking of any big ships
		self:BigShipTracker_Remove(shipname)

	end

	function Movements:OnSimulation()

		local current_time = mn.getMissionTime()
		if current_time > 0.1 then
			--update rotations --now done on Simulation
			if self.Active_Rotations_Sum > 0 then
				self:Run_Rotation()
			end
			--update locations --now done on Simulation
			if self.Active_Locations_Sum > 0 then
				self:Run_LocationMove()
			end
			--update current time and check waypoints
			if current_time > self.Time_Previous_Check + self.G_Time_Check_Interval then
				self.Time_Previous_Check = current_time
				--check waypoints tracking ships
				if self.Active_Wpts_trk_Objects_Sum > 0 then
					self:Check_Waypoint_Track_Object()
				end 
				--check ships tracking waypoints
				if self.Active_Ships_trk_Wpts_Sum > 0 then
					self:Check_Ship_trk_Wpt()
				end
			end
		end	

	end

	function Movements:OnFrameDebug()

		if not Movements.UseDebugMode then return end

		--get player target, and if on movement order list draw info
		local ply = hv.Player
		if ply == nil then return end
		if not ply:isValid() then return end

		local ply_target = ply.Target
		if ply_target == nil then return end
		if not ply_target:isValid() then return end

		local target_name = tostring(ply_target) or ""
		local ship_tracking_info = self.Active_Ships_trk_Wpts[target_name]
		if ship_tracking_info == nil then return end

		if ply_target:getBreedName() ~= "Ship" then return end
		local targeted_ship = mn.Ships[target_name]
		if targeted_ship == nil then return end
		if not targeted_ship:isValid() then return end
		if targeted_ship:isArrivingWarp() or targeted_ship:isDying() or targeted_ship:isDepartingWarp() then return end

		--ship is valid and has order and stable, so draw line
		local wp_name = ship_tracking_info.StW_OUT_wp_path_name or ""
		local wp_path = mn.WaypointLists[wp_name]

		if wp_path == nil then return end
		if not wp_path:isValid() then return end
		local last_wp = wp_path[ship_tracking_info.StW_OUT_num_waypoints]
		if last_wp == nil then return end
		if not last_wp:isValid() then return end

		gr.setColor(255, 255, 255)
		gr.draw3dLine(targeted_ship.Position, last_wp.Position, true, 2, 1.5)

		local screenwidth = gr.getScreenWidth()
		gr.drawString("Movements information for ship "..target_name, screenwidth/2, 50)
		gr.drawString("  Waypoint speed cap is "..targeted_ship.WaypointSpeedCap)
		gr.drawString("  Target name is "..tostring(ship_tracking_info.StW_OUT_final_pbh_target_name))

	end

--
--Hook Functions
	engine.addHook("On Simulation", function()
		if Movements and Movements.is_enabled then
			Movements:OnSimulation()
		end
	end)

	engine.addHook("On Gameplay Start", function() 
		if Movements then
			Movements:Initiate()
		end
	end)

	engine.addHook("On Mission End", function() 
		if Movements then
			Movements:Initiate()
		end
	end)

	engine.addHook("On Ship Arrive", function() 
		if Movements and Movements.is_enabled then
			Movements:BigShipTracker_Add(hv.Ship)
		end
	end)

	engine.addHook("On Waypoints Done", function() 
		if Movements and Movements.is_enabled then
			local hs = hv.Ship
			local hswpp = hv.Waypointlist
			if hs ~= nil and hs:isValid() and hswpp ~= nil and hswpp:isValid() then
				Movements:On_Waypoints_Done(hs.Name, hswpp.Name)
			end
		end
	end)

	engine.addHook("On Ship Death Started", function() 
		if Movements and Movements.is_enabled then
			Movements:Ship_DoD_Remove(hv.Ship)
		end
	end)

	engine.addHook("On Warp Out", function() 
		--also checking for warpout just because it triggers sooner
		--perfectly safe to remove many times because it only removes it if it is on the list
		if Movements and Movements.is_enabled then
			Movements:Ship_DoD_Remove(hv.Self)
		end	
	end)

	engine.addHook("On Ship Depart", function() 
		if Movements and Movements.is_enabled then
			Movements:Ship_DoD_Remove(hv.Ship)
		end	
	end)

	engine.addHook("On Goals Cleared", function() 
		if Movements and Movements.is_enabled then
			local hook_ship = hv.Ship
			if hook_ship ~= nil and hook_ship:isValid() then
				local shipname = hook_ship.Name
				Movements:Remove_Rotation(shipname, true)
				Movements:Remove_LocationMove(shipname, true)
				Movements:Remove_Ship_Track_Waypoint(shipname)
			end
		end		
	end)

	if Movements.UseDebugMode then
		engine.addHook("On HUD Draw", function() 
				Movements:OnFrameDebug()
			end,
			{State="GS_STATE_GAME_PLAY"}
		)
	end

