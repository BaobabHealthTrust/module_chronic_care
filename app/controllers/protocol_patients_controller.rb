
class ProtocolPatientsController < ApplicationController

	def assessment

	@patient = Patient.find(params[:patient_id]) rescue nil

	redirect_to '/encounters/no_patient' and return if @patient.nil?

if params[:user_id].nil?
	redirect_to '/encounters/no_user' and return
	end

	@user = User.find(params[:user_id]) rescue nil?

	redirect_to '/encounters/no_patient' and return if @user.nil?
	

	end

	def hiv_status

	@patient = Patient.find(params[:patient_id]) rescue nil

	redirect_to '/encounters/no_patient' and return if @patient.nil?

if params[:user_id].nil?
	redirect_to '/encounters/no_user' and return
	end

	@user = User.find(params[:user_id]) rescue nil?

	redirect_to '/encounters/no_patient' and return if @user.nil?
	

	end

	def treatment

	@patient = Patient.find(params[:patient_id]) rescue nil

	redirect_to '/encounters/no_patient' and return if @patient.nil?

if params[:user_id].nil?
	redirect_to '/encounters/no_user' and return
	end

	@user = User.find(params[:user_id]) rescue nil?

	redirect_to '/encounters/no_patient' and return if @user.nil?
	

	end

	def lab_results

	@patient = Patient.find(params[:patient_id]) rescue nil

	redirect_to '/encounters/no_patient' and return if @patient.nil?

if params[:user_id].nil?
	redirect_to '/encounters/no_user' and return
	end

	@user = User.find(params[:user_id]) rescue nil?

	redirect_to '/encounters/no_patient' and return if @user.nil?
	

	end

	def vitals

	@patient = Patient.find(params[:patient_id]) rescue nil

	redirect_to '/encounters/no_patient' and return if @patient.nil?

if params[:user_id].nil?
	redirect_to '/encounters/no_user' and return
	end

	@user = User.find(params[:user_id]) rescue nil?

	redirect_to '/encounters/no_patient' and return if @user.nil?
	

	end

	def outcomes

	@patient = Patient.find(params[:patient_id]) rescue nil

	redirect_to '/encounters/no_patient' and return if @patient.nil?

if params[:user_id].nil?
	redirect_to '/encounters/no_user' and return
	end

	@user = User.find(params[:user_id]) rescue nil?

	redirect_to '/encounters/no_patient' and return if @user.nil?
	

	end

	def complications

	@patient = Patient.find(params[:patient_id]) rescue nil

	redirect_to '/encounters/no_patient' and return if @patient.nil?

if params[:user_id].nil?
	redirect_to '/encounters/no_user' and return
	end

	@user = User.find(params[:user_id]) rescue nil?

	redirect_to '/encounters/no_patient' and return if @user.nil?
	

	end

end
