defmodule Clothes.Server do
  use GenServer, restart: :temporary

  def start_link(user_id) do
    IO.puts("Starting clothes server for #{user_id}")
    GenServer.start_link(Clothes.Server, user_id, name: via_tuple(user_id))
  end

  defp via_tuple(user_id) do
    Clothes.ProcessRegistry.via_tuple({__MODULE__, user_id})
  end

  def add_item(pid, new_item) do
    GenServer.call(pid, {:add_item, new_item})
  end

  def all(pid) do
    GenServer.call(pid, :clothes)
  end

  def clothes(pid, name, color) do
    GenServer.call(pid, {:clothes, name, color})
  end

  def update_item(pid, item_id, updater_fun) do
    GenServer.cast(pid, {:update_item, item_id, updater_fun})
  end

  def update_item(pid, %{} = new_item) do
    GenServer.cast(pid, {:update_item, new_item})
  end

  def delete_item(pid, item_id) do
    GenServer.cast(pid, {:delete_item, item_id})
  end

  @expiry_idle_timeout :timer.seconds(60)

  @impl GenServer
  def init(user_id) do
    send(self(), :real_init)
    {:ok, {user_id, nil}, @expiry_idle_timeout}
  end

  @impl GenServer
  def handle_info(:real_init, {user_id, _}) do
    state = {user_id, Clothes.Database.get(user_id) || Clothes.new()}
    {:noreply, state, @expiry_idle_timeout}
  end

  @impl GenServer
  def handle_info(:timeout, {user_id, items}) do
    IO.puts("Stopping clothes server for #{user_id}")
    {:stop, :normal, {user_id, items}}
  end

  @impl GenServer
  def handle_cast({:update_item, item_id, updater_fun}, {user_id, items}) do
    new_clothes = Clothes.update_item(items, item_id, updater_fun)
    Clothes.Database.store(user_id, new_clothes)
    {:noreply, {user_id, new_clothes}, @expiry_idle_timeout}
  end

  @impl GenServer
  def handle_cast({:update_item, new_item}, {user_id, items}) do
    new_clothes = Clothes.update_item(items, new_item)
    Clothes.Database.store(user_id, new_clothes)
    {:noreply, {user_id, new_clothes}, @expiry_idle_timeout}
  end

  @impl GenServer
  def handle_cast({:delete_item, item_id}, {user_id, items}) do
    new_clothes = Clothes.delete_item(items, item_id)
    Clothes.Database.store(user_id, new_clothes)
    {:noreply, {user_id, new_clothes}, @expiry_idle_timeout}
  end

  @impl GenServer
  def handle_call(:clothes, _, {user_id, items}) do
    {:reply, Clothes.all(items), {user_id, items}, @expiry_idle_timeout}
  end

  @impl GenServer
  def handle_call({:clothes, name, color}, _, {user_id, items}) do
    {:reply, Clothes.clothes(items, name, color), {user_id, items}, @expiry_idle_timeout}
  end

  @impl GenServer
  def handle_call({:add_item, new_item}, _, {user_id, items}) do
    {new_clothes, item_id} = Clothes.add_item(items, new_item)
    Clothes.Database.store(user_id, new_clothes)
    {:reply, item_id, {user_id, new_clothes}, @expiry_idle_timeout}
  end
end
