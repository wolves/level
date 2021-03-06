defmodule Level.Resolvers do
  @moduledoc """
  Functions for loading connections between resources, designed to be used in
  GraphQL query resolution.
  """

  import Absinthe.Resolution.Helpers
  import Ecto.Query, warn: false
  import Level.Gettext

  alias Level.Nudges
  alias Level.Pagination
  alias Level.Posts
  alias Level.Repo
  alias Level.Resolvers.GroupConnection
  alias Level.Resolvers.GroupMembershipConnection
  alias Level.Resolvers.PostConnection
  alias Level.Resolvers.ReactionConnection
  alias Level.Resolvers.ReplyConnection
  alias Level.Resolvers.SearchConnection
  alias Level.Resolvers.SpaceUserConnection
  alias Level.Resolvers.UserGroupMembershipConnection
  alias Level.Schemas.Group
  alias Level.Schemas.GroupUser
  alias Level.Schemas.Post
  alias Level.Schemas.PostUser
  alias Level.Schemas.Reply
  alias Level.Schemas.ReplyView
  alias Level.Schemas.Space
  alias Level.Schemas.SpaceBot
  alias Level.Schemas.SpaceUser
  alias Level.Schemas.Tutorial
  alias Level.Schemas.User
  alias Level.Schemas.UserMention
  alias Level.Spaces
  alias Level.Tutorials

  @typedoc "A info map for Absinthe GraphQL"
  @type info :: %{context: %{current_user: User.t(), loader: Dataloader.t()}}

  @typedoc "The return value for paginated connections"
  @type paginated_result :: {:ok, Pagination.Result.t()} | {:error, String.t()}

  @typedoc "The return value for a dataloader resolver"
  @type dataloader_result :: {:middleware, any(), any()}

  @doc """
  Fetches a space by id or slug.
  """
  @spec space(map(), info()) :: {:ok, Space.t()} | {:error, String.t()}
  def space(%{id: id} = _args, %{context: %{current_user: user}} = _info) do
    case Spaces.get_space(user, id) do
      {:ok, %{space: space}} ->
        {:ok, space}

      error ->
        error
    end
  end

  def space(%{slug: slug} = _args, %{context: %{current_user: user}} = _info) do
    case Spaces.get_space_by_slug(user, slug) do
      {:ok, %{space: space}} ->
        {:ok, space}

      error ->
        error
    end
  end

  def space(_args, _info) do
    {:error, dgettext("errors", "You must provide an `id` or `slug` to lookup a space.")}
  end

  @doc """
  Fetches a space user.
  """
  @spec space_user(map(), info()) :: {:ok, SpaceUser.t()} | {:error, String.t()}
  def space_user(%{space_id: id} = _args, %{context: %{current_user: user}} = _info) do
    case Spaces.get_space(user, id) do
      {:ok, %{space_user: space_user}} ->
        {:ok, space_user}

      error ->
        error
    end
  end

  def space_user(%{space_slug: slug} = _args, %{context: %{current_user: user}} = _info) do
    case Spaces.get_space_by_slug(user, slug) do
      {:ok, %{space_user: space_user}} ->
        {:ok, space_user}

      error ->
        error
    end
  end

  def space_user(%{id: space_user_id} = _args, %{context: %{current_user: user}} = _info) do
    Spaces.get_space_user(user, space_user_id)
  end

  def space_user(_args, _info) do
    {:error,
     dgettext("errors", "You must provide an argument by which to look up the space user.")}
  end

  @doc """
  Fetches a group.
  """
  @spec group(map(), info()) :: {:ok, Group.t()} | {:error, String.t()}
  def group(%{id: id} = _args, %{context: %{current_user: user}}) do
    Level.Groups.get_group(user, id)
  end

  def group(%{space_slug: space_slug, name: name} = _args, %{context: %{current_user: user}}) do
    Level.Groups.get_group_by_name(user, space_slug, name)
  end

  def group(_args, _) do
    {:error, dgettext("errors", "You must provide an `id` or `space_slug` and `name` combo.")}
  end

  @doc """
  Fetches space users belonging to a given user or a given space.
  """
  @spec space_users(User.t(), map(), info()) :: paginated_result()
  def space_users(%User{} = user, args, %{context: %{current_user: _user}} = info) do
    SpaceUserConnection.get(user, struct(SpaceUserConnection, args), info)
  end

  @spec space_users(Space.t(), map(), info()) :: paginated_result()
  def space_users(%Space{} = space, args, %{context: %{current_user: _user}} = info) do
    SpaceUserConnection.get(space, struct(SpaceUserConnection, args), info)
  end

  @doc """
  Fetches featured space members.
  """
  @spec featured_space_users(Space.t(), map(), info()) :: {:ok, [SpaceUser.t()]} | no_return()
  def featured_space_users(%Space{} = space, _args, %{context: %{current_user: _user}} = _info) do
    Level.Spaces.list_featured_users(space)
  end

  @doc """
  Fetches groups for given a space that are visible to the current user.
  """
  @spec groups(Space.t(), map(), info()) :: paginated_result()
  def groups(%Space{} = space, args, %{context: %{current_user: _user}} = info) do
    GroupConnection.get(space, struct(GroupConnection, args), info)
  end

  @doc """
  Fetches group memberships.
  """
  @spec group_memberships(User.t(), map(), info()) :: paginated_result()
  def group_memberships(%User{} = user, args, %{context: %{current_user: _user}} = info) do
    UserGroupMembershipConnection.get(user, struct(UserGroupMembershipConnection, args), info)
  end

  @spec group_memberships(Group.t(), map(), info()) :: paginated_result()
  def group_memberships(%Group{} = user, args, %{context: %{current_user: _user}} = info) do
    GroupMembershipConnection.get(user, struct(GroupMembershipConnection, args), info)
  end

  @doc """
  Fetches featured group memberships.
  """
  @spec featured_group_memberships(Group.t(), map(), info()) ::
          {:ok, [GroupUser.t()]} | no_return()
  def featured_group_memberships(group, _args, _info) do
    Level.Groups.list_featured_memberships(group)
  end

  @doc """
  Fetches replies to a given post.
  """
  @spec replies(Post.t(), map(), info()) :: paginated_result()
  def replies(%Post{} = post, args, info) do
    ReplyConnection.get(post, struct(ReplyConnection, args), info)
  end

  @doc """
  Fetches reactions to a given post or reply.
  """
  @spec reactions(Post.t() | Reply.t(), map(), info()) :: paginated_result()
  def reactions(post_or_reply, args, info) do
    ReactionConnection.get(post_or_reply, struct(ReactionConnection, args), info)
  end

  @doc """
  Fetches a post by id.
  """
  @spec post(Space.t(), map(), info()) :: {:ok, Post.t()} | {:error, String.t()}
  def post(%Space{} = space, %{id: id} = _args, %{context: %{current_user: user}} = _info) do
    with {:ok, %{space_user: space_user}} <- Spaces.get_space(user, space.id),
         {:ok, post} <- Level.Posts.get_post(space_user, id) do
      {:ok, post}
    else
      error ->
        error
    end
  end

  @doc """
  Fetches mentions for the current user in a given scope.
  """
  @spec mentions(Post.t(), map(), info()) :: dataloader_result()
  def mentions(%Post{} = post, _args, %{context: %{loader: loader}}) do
    dataloader_one(loader, :db, {:many, UserMention}, post_id: post.id)
  end

  @doc """
  Renders the body of a post.
  """
  @spec render_markdown(Post.t(), map, info()) :: dataloader_result()
  def render_markdown(%Post{} = post, _, %{context: %{loader: loader, current_user: user}}) do
    batch_key = Space
    item_key = post.space_id

    loader
    |> Dataloader.load(:db, batch_key, item_key)
    |> on_load(fn loader ->
      loader
      |> Dataloader.get(:db, batch_key, item_key)
      |> do_rendering(post.body, user)
    end)
  end

  @spec render_markdown(Reply.t(), map, info()) :: dataloader_result()
  def render_markdown(%Reply{} = reply, _, %{context: %{loader: loader, current_user: user}}) do
    batch_key = Space
    item_key = reply.space_id

    loader
    |> Dataloader.load(:db, batch_key, item_key)
    |> on_load(fn loader ->
      loader
      |> Dataloader.get(:db, batch_key, item_key)
      |> do_rendering(reply.body, user)
    end)
  end

  defp do_rendering(space, body, user) do
    Posts.render_body(body, %{space: space, user: user})
  end

  @doc """
  Determines whether the current user has viewed the reply.
  """
  @spec has_viewed_reply(Reply.t(), map(), info()) :: dataloader_result()
  def has_viewed_reply(%Reply{} = reply, _args, %{context: %{loader: loader}}) do
    source_name = :db
    batch_key = {:many, ReplyView}
    item_key = [reply_id: reply.id]

    loader
    |> Dataloader.load(source_name, batch_key, item_key)
    |> on_load(fn loader ->
      loader
      |> Dataloader.get(source_name, batch_key, item_key)
      |> handle_reply_views_fetched()
    end)
  end

  defp handle_reply_views_fetched([]), do: {:ok, false}
  defp handle_reply_views_fetched(_), do: {:ok, true}

  @doc """
  Fetches posts accessible by the current user.
  """
  @spec posts(Space.t() | Group.t(), map(), info()) :: paginated_result()
  def posts(%Space{} = space, args, info) do
    PostConnection.get(space, struct(PostConnection, args), info)
  end

  def posts(%Group{} = group, args, info) do
    PostConnection.get(group, struct(PostConnection, args), info)
  end

  @doc """
  Fetches the current subscription state for a post.
  """
  @spec subscription_state(Post.t(), map(), info()) :: dataloader_result()
  def subscription_state(%Post{} = post, _, %{context: %{loader: loader}}) do
    post_user_dataloader(loader, post, &handle_subscription_state/1)
  end

  defp handle_subscription_state(%PostUser{subscription_state: state}), do: {:ok, state}
  defp handle_subscription_state(_), do: {:ok, "NOT_SUBSCRIBED"}

  @doc """
  Fetches the current inbox state for a post.
  """
  @spec inbox_state(Post.t(), map(), info()) :: dataloader_result()
  def inbox_state(%Post{} = post, _, %{context: %{loader: loader}}) do
    post_user_dataloader(loader, post, &handle_inbox_state/1)
  end

  defp handle_inbox_state(%PostUser{inbox_state: state}), do: {:ok, state}
  defp handle_inbox_state(_), do: {:ok, "EXCLUDED"}

  @doc """
  Fetches a space user by user id.
  """
  @spec space_user_by_user_id(map(), info()) :: {:ok, SpaceUser.t()} | {:error, String.t()}
  def space_user_by_user_id(%{space_id: space_id, user_id: user_id}, %{
        context: %{current_user: user}
      }) do
    user
    |> Spaces.space_users_base_query()
    |> where([su], su.user_id == ^user_id and su.space_id == ^space_id)
    |> Repo.one()
    |> handle_space_user_by_user_id()
  end

  defp handle_space_user_by_user_id(%SpaceUser{} = space_user) do
    {:ok, space_user}
  end

  defp handle_space_user_by_user_id(nil) do
    {:error, dgettext("errors", "User not found")}
  end

  @doc """
  Determines whether the current user can edit the post.
  """
  @spec can_edit_post(Post.t(), map(), info()) :: dataloader_result()
  def can_edit_post(%Post{} = post, _, %{context: %{loader: loader, current_user: user}}) do
    batch_key = SpaceUser
    item_key = post.space_user_id

    loader
    |> Dataloader.load(:db, batch_key, item_key)
    |> on_load(fn loader ->
      loader
      |> Dataloader.get(:db, batch_key, item_key)
      |> check_edit_post_permissions(user)
    end)
  end

  defp check_edit_post_permissions(%SpaceUser{} = post_author, current_user) do
    {:ok, Posts.can_edit?(current_user, post_author)}
  end

  defp check_edit_post_permissions(_, _current_user) do
    {:ok, false}
  end

  @doc """
  Determines whether the current user can edit the reply.
  """
  @spec can_edit_reply(Reply.t(), map(), info()) :: dataloader_result()
  def can_edit_reply(%Reply{} = reply, _, %{context: %{loader: loader, current_user: user}}) do
    batch_key = SpaceUser
    item_key = reply.space_user_id

    loader
    |> Dataloader.load(:db, batch_key, item_key)
    |> on_load(fn loader ->
      loader
      |> Dataloader.get(:db, batch_key, item_key)
      |> check_edit_reply_permissions(user)
    end)
  end

  defp check_edit_reply_permissions(%SpaceUser{} = post_author, current_user) do
    {:ok, Posts.can_edit?(current_user, post_author)}
  end

  defp check_edit_reply_permissions(_, _current_user) do
    {:ok, false}
  end

  @doc """
  Determines whether the current user has reacted to the post or reply.
  """
  @spec has_reacted(Post.t(), map(), info()) :: {:ok, boolean()}
  def has_reacted(%Post{} = post, _, %{context: %{current_user: user}}) do
    {:ok, Posts.reacted?(user, post)}
  end

  @spec has_reacted(Reply.t(), map(), info()) :: {:ok, boolean()}
  def has_reacted(%Reply{} = reply, _, %{context: %{current_user: user}}) do
    {:ok, Posts.reacted?(user, reply)}
  end

  @doc """
  Fetches search results.
  """
  @spec search(Space.t(), map(), info()) :: paginated_result()
  def search(%Space{} = space, args, info) do
    SearchConnection.get(space, struct(SearchConnection, args), info)
  end

  @doc """
  Fetches the author of a post.
  """
  @spec post_author(Post.t(), map(), info()) :: dataloader_result()
  def post_author(%Post{space_user_id: space_user_id} = post, _, %{context: %{loader: loader}})
      when is_binary(space_user_id) do
    loader
    |> Dataloader.load(:db, SpaceUser, space_user_id)
    |> on_load(fn loader ->
      actor =
        loader
        |> Dataloader.get(:db, SpaceUser, space_user_id)

      author = %{
        actor: actor,
        overrides: %{
          display_name: post.display_name,
          initials: post.initials,
          avatar_color: post.avatar_color
        }
      }

      {:ok, author}
    end)
  end

  def post_author(%Post{space_bot_id: space_bot_id} = post, _, %{context: %{loader: loader}})
      when is_binary(space_bot_id) do
    loader
    |> Dataloader.load(:db, SpaceBot, space_bot_id)
    |> on_load(fn loader ->
      actor =
        loader
        |> Dataloader.get(:db, SpaceBot, space_bot_id)

      author = %{
        actor: actor,
        overrides: %{
          display_name: post.display_name,
          initials: post.initials,
          avatar_color: post.avatar_color
        }
      }

      {:ok, author}
    end)
  end

  @doc """
  Fetches the author of a reply.
  """
  @spec reply_author(Reply.t(), map(), info()) :: dataloader_result()
  def reply_author(%Reply{space_user_id: space_user_id}, _, %{context: %{loader: loader}})
      when is_binary(space_user_id) do
    loader
    |> Dataloader.load(:db, SpaceUser, space_user_id)
    |> on_load(fn loader ->
      actor =
        loader
        |> Dataloader.get(:db, SpaceUser, space_user_id)

      author = %{
        actor: actor,
        overrides: %{
          display_name: nil,
          initials: nil,
          avatar_color: nil
        }
      }

      {:ok, author}
    end)
  end

  def reply_author(%Reply{space_bot_id: space_bot_id}, _, %{context: %{loader: loader}})
      when is_binary(space_bot_id) do
    loader
    |> Dataloader.load(:db, SpaceBot, space_bot_id)
    |> on_load(fn loader ->
      actor =
        loader
        |> Dataloader.get(:db, SpaceBot, space_bot_id)

      author = %{
        actor: actor,
        overrides: %{
          display_name: nil,
          initials: nil,
          avatar_color: nil
        }
      }

      {:ok, author}
    end)
  end

  @doc """
  Determines whether the current user is allowed to update the resource.
  """
  @spec can_update?(Space.t(), map(), info()) :: {:ok, boolean()}
  def can_update?(%Space{} = space, _, %{context: %{current_user: user}}) do
    case Spaces.get_space_user(user, space) do
      {:ok, space_user} ->
        {:ok, Spaces.can_update?(space_user)}

      _ ->
        {:ok, false}
    end
  end

  @doc """
  Determines whether a space user is allowed to manage members.
  """
  @spec can_manage_members?(SpaceUser.t(), map(), info()) :: {:ok, boolean()}
  def can_manage_members?(%SpaceUser{} = space_user, _, %{context: %{current_user: _user}}) do
    {:ok, Spaces.can_manage_members?(space_user)}
  end

  @doc """
  Determines whether a space user is allowed to manage owners.
  """
  @spec can_manage_owners?(SpaceUser.t(), map(), info()) :: {:ok, boolean()}
  def can_manage_owners?(%SpaceUser{} = space_user, _, %{context: %{current_user: _user}}) do
    {:ok, Spaces.can_manage_owners?(space_user)}
  end

  @doc """
  Fetches a tutorial.
  """
  @spec tutorial(SpaceUser.t(), map(), info()) :: {:ok, Tutorial.t() | nil}
  def tutorial(%SpaceUser{} = space_user, %{key: key}, %{context: %{current_user: user}}) do
    if space_user.user_id == user.id do
      Tutorials.get_tutorial(space_user, key)
    else
      {:ok, nil}
    end
  end

  @doc """
  Fetches nudges for a space user.
  """
  @spec nudges(SpaceUser.t(), map(), info()) :: {:ok, [Nudge.t()] | nil}
  def nudges(%SpaceUser{} = space_user, _args, %{context: %{current_user: user}}) do
    if space_user.user_id == user.id do
      {:ok, Nudges.list_nudges(space_user)}
    else
      {:ok, nil}
    end
  end

  # Dataloader helpers

  defp dataloader_one(loader, source_name, batch_key, item_key) do
    loader
    |> Dataloader.load(source_name, batch_key, item_key)
    |> on_load(fn loader ->
      loader
      |> Dataloader.get(source_name, batch_key, item_key)
      |> tuplize()
    end)
  end

  defp tuplize(value), do: {:ok, value}

  defp post_user_dataloader(loader, post, handler_fn) do
    batch_key = {:one, PostUser}
    item_key = [post_id: post.id]

    loader
    |> Dataloader.load(:db, batch_key, item_key)
    |> on_load(fn loader ->
      loader
      |> Dataloader.get(:db, batch_key, item_key)
      |> handler_fn.()
    end)
  end
end
